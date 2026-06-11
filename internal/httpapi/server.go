package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"strings"
	"time"

	"github.com/Toridesu/aws-production-web-platform/internal/auth"
	"github.com/Toridesu/aws-production-web-platform/internal/task"
	"github.com/google/uuid"
)

type HealthChecker interface {
	Ping(ctx context.Context) error
}

type TaskService interface {
	List(ctx context.Context, ownerSub string) ([]task.Task, error)
	Create(ctx context.Context, ownerSub string, input task.CreateInput) (task.Task, error)
	Get(ctx context.Context, ownerSub string, id uuid.UUID) (task.Task, error)
	Update(ctx context.Context, ownerSub string, id uuid.UUID, input task.UpdateInput) (task.Task, error)
	Delete(ctx context.Context, ownerSub string, id uuid.UUID) error
}

type Server struct {
	logger        *slog.Logger
	healthChecker HealthChecker
	tasks         TaskService
	verifier      auth.Verifier
}

func New(logger *slog.Logger, healthChecker HealthChecker, tasks TaskService, verifier auth.Verifier) http.Handler {
	server := &Server{
		logger:        logger,
		healthChecker: healthChecker,
		tasks:         tasks,
		verifier:      verifier,
	}

	mux := http.NewServeMux()
	mux.HandleFunc("GET /health/live", server.live)
	mux.HandleFunc("GET /health/ready", server.ready)
	mux.Handle("GET /api/v1/tasks", server.requireScope("tasks.read", http.HandlerFunc(server.listTasks)))
	mux.Handle("POST /api/v1/tasks", server.requireScope("tasks.write", http.HandlerFunc(server.createTask)))
	mux.Handle("GET /api/v1/tasks/{id}", server.requireScope("tasks.read", http.HandlerFunc(server.getTask)))
	mux.Handle("PATCH /api/v1/tasks/{id}", server.requireScope("tasks.write", http.HandlerFunc(server.updateTask)))
	mux.Handle("DELETE /api/v1/tasks/{id}", server.requireScope("tasks.write", http.HandlerFunc(server.deleteTask)))

	return requestID(recoverPanic(logger, accessLog(logger, requestTimeout(10*time.Second, mux))))
}

func (s *Server) live(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (s *Server) ready(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
	defer cancel()

	if err := s.healthChecker.Ping(ctx); err != nil {
		s.logger.Error("readiness check failed", "request_id", requestIDFromContext(r.Context()), "error", err)
		writeError(w, r, http.StatusServiceUnavailable, "not_ready", "service is not ready")
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (s *Server) listTasks(w http.ResponseWriter, r *http.Request) {
	items, err := s.tasks.List(r.Context(), mustPrincipal(r).Subject)
	if err != nil {
		s.handleError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"data": items})
}

func (s *Server) createTask(w http.ResponseWriter, r *http.Request) {
	var request struct {
		Title       string     `json:"title"`
		Description string     `json:"description"`
		DueAt       *time.Time `json:"due_at"`
	}
	if err := decodeJSON(w, r, &request); err != nil {
		writeError(w, r, http.StatusBadRequest, "invalid_json", "request body must be valid JSON")
		return
	}

	item, err := s.tasks.Create(r.Context(), mustPrincipal(r).Subject, task.CreateInput{
		Title: request.Title, Description: request.Description, DueAt: request.DueAt,
	})
	if err != nil {
		s.handleError(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"data": item})
}

func (s *Server) getTask(w http.ResponseWriter, r *http.Request) {
	id, ok := parseTaskID(w, r)
	if !ok {
		return
	}
	item, err := s.tasks.Get(r.Context(), mustPrincipal(r).Subject, id)
	if err != nil {
		s.handleError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"data": item})
}

func (s *Server) updateTask(w http.ResponseWriter, r *http.Request) {
	id, ok := parseTaskID(w, r)
	if !ok {
		return
	}

	var request struct {
		Title       *string         `json:"title"`
		Description *string         `json:"description"`
		Status      *task.Status    `json:"status"`
		DueAt       json.RawMessage `json:"due_at"`
	}
	if err := decodeJSON(w, r, &request); err != nil {
		writeError(w, r, http.StatusBadRequest, "invalid_json", "request body must be valid JSON")
		return
	}

	input := task.UpdateInput{Title: request.Title, Description: request.Description, Status: request.Status}
	if request.DueAt != nil {
		input.DueAtSet = true
		if string(request.DueAt) != "null" {
			var dueAt time.Time
			if err := json.Unmarshal(request.DueAt, &dueAt); err != nil {
				writeError(w, r, http.StatusBadRequest, "validation_error", "due_at must be RFC3339 timestamp or null")
				return
			}
			input.DueAt = &dueAt
		}
	}

	item, err := s.tasks.Update(r.Context(), mustPrincipal(r).Subject, id, input)
	if err != nil {
		s.handleError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"data": item})
}

func (s *Server) deleteTask(w http.ResponseWriter, r *http.Request) {
	id, ok := parseTaskID(w, r)
	if !ok {
		return
	}
	if err := s.tasks.Delete(r.Context(), mustPrincipal(r).Subject, id); err != nil {
		s.handleError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) requireScope(scope string, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		header := strings.TrimSpace(r.Header.Get("Authorization"))
		if !strings.HasPrefix(header, "Bearer ") {
			writeError(w, r, http.StatusUnauthorized, "unauthorized", "valid bearer token is required")
			return
		}

		principal, err := s.verifier.Verify(r.Context(), strings.TrimSpace(strings.TrimPrefix(header, "Bearer ")))
		if err != nil {
			writeError(w, r, http.StatusUnauthorized, "unauthorized", "valid bearer token is required")
			return
		}
		if !principal.HasScope(scope) {
			writeError(w, r, http.StatusForbidden, "forbidden", "required scope is missing")
			return
		}
		next.ServeHTTP(w, r.WithContext(auth.WithPrincipal(r.Context(), principal)))
	})
}

func (s *Server) handleError(w http.ResponseWriter, r *http.Request, err error) {
	switch {
	case errors.Is(err, task.ErrValidation):
		writeError(w, r, http.StatusBadRequest, "validation_error", "request values are invalid")
	case errors.Is(err, task.ErrNotFound):
		writeError(w, r, http.StatusNotFound, "not_found", "task was not found")
	case errors.Is(err, context.DeadlineExceeded):
		writeError(w, r, http.StatusGatewayTimeout, "timeout", "request timed out")
	default:
		s.logger.Error("request failed", "request_id", requestIDFromContext(r.Context()), "error", err)
		writeError(w, r, http.StatusInternalServerError, "internal_error", "internal server error")
	}
}

func parseTaskID(w http.ResponseWriter, r *http.Request) (uuid.UUID, bool) {
	id, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		writeError(w, r, http.StatusBadRequest, "validation_error", "id must be a UUID")
		return uuid.Nil, false
	}
	return id, true
}

func mustPrincipal(r *http.Request) auth.Principal {
	principal, _ := auth.PrincipalFromContext(r.Context())
	return principal
}

func decodeJSON(w http.ResponseWriter, r *http.Request, destination any) error {
	decoder := json.NewDecoder(http.MaxBytesReader(w, r.Body, 1<<20))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(destination); err != nil {
		return err
	}
	if err := decoder.Decode(&struct{}{}); !errors.Is(err, io.EOF) {
		return errors.New("request body must contain one JSON object")
	}
	return nil
}
