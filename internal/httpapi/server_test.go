package httpapi

import (
	"bytes"
	"context"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/Toridesu/aws-production-web-platform/internal/auth"
	"github.com/Toridesu/aws-production-web-platform/internal/task"
	"github.com/google/uuid"
)

type fakeHealthChecker struct {
	err error
}

func (f fakeHealthChecker) Ping(context.Context) error {
	return f.err
}

type fakeTaskService struct {
	createdOwner string
	updatedInput task.UpdateInput
	listPanic    bool
}

func (f *fakeTaskService) List(context.Context, string) ([]task.Task, error) {
	if f.listPanic {
		panic("test panic")
	}
	return []task.Task{}, nil
}

func (f *fakeTaskService) Create(_ context.Context, ownerSub string, input task.CreateInput) (task.Task, error) {
	f.createdOwner = ownerSub
	return task.Task{ID: uuid.New(), Title: input.Title, Status: task.StatusTodo}, nil
}

func (f *fakeTaskService) Get(context.Context, string, uuid.UUID) (task.Task, error) {
	return task.Task{}, task.ErrNotFound
}

func (f *fakeTaskService) Update(_ context.Context, _ string, id uuid.UUID, input task.UpdateInput) (task.Task, error) {
	f.updatedInput = input
	return task.Task{ID: id, Title: "task", Status: task.StatusTodo, DueAt: input.DueAt}, nil
}

func (f *fakeTaskService) Delete(context.Context, string, uuid.UUID) error {
	return nil
}

func TestLiveHealthCheck(t *testing.T) {
	t.Parallel()

	response := performRequest(t, New(testLogger(), fakeHealthChecker{}, &fakeTaskService{}, auth.DevVerifier{}), http.MethodGet, "/health/live", "", "")
	if response.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusOK)
	}
	if response.Header().Get("X-Request-ID") == "" {
		t.Fatal("X-Request-ID header is empty")
	}
}

func TestReadyHealthCheckFailure(t *testing.T) {
	t.Parallel()

	response := performRequest(t, New(testLogger(), fakeHealthChecker{err: errors.New("database unavailable")}, &fakeTaskService{}, auth.DevVerifier{}), http.MethodGet, "/health/ready", "", "")
	if response.Code != http.StatusServiceUnavailable {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusServiceUnavailable)
	}
}

func TestTasksRequireAuthentication(t *testing.T) {
	t.Parallel()

	response := performRequest(t, New(testLogger(), fakeHealthChecker{}, &fakeTaskService{}, auth.DevVerifier{}), http.MethodGet, "/api/v1/tasks", "", "")
	if response.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusUnauthorized)
	}
}

func TestTasksRequireWriteScope(t *testing.T) {
	t.Parallel()

	response := performRequest(t, New(testLogger(), fakeHealthChecker{}, &fakeTaskService{}, auth.DevVerifier{}), http.MethodPost, "/api/v1/tasks", `{"title":"learn Go"}`, "user-a|tasks.read")
	if response.Code != http.StatusForbidden {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusForbidden)
	}
}

func TestCreateTaskUsesAuthenticatedSubject(t *testing.T) {
	t.Parallel()

	service := &fakeTaskService{}
	response := performRequest(t, New(testLogger(), fakeHealthChecker{}, service, auth.DevVerifier{}), http.MethodPost, "/api/v1/tasks", `{"title":"learn Go"}`, "user-a|tasks.write")
	if response.Code != http.StatusCreated {
		t.Fatalf("status = %d, want %d; body=%s", response.Code, http.StatusCreated, response.Body.String())
	}
	if service.createdOwner != "user-a" {
		t.Fatalf("owner = %q, want user-a", service.createdOwner)
	}
}

func TestCreateTaskRejectsInvalidJSON(t *testing.T) {
	t.Parallel()

	response := performRequest(t, New(testLogger(), fakeHealthChecker{}, &fakeTaskService{}, auth.DevVerifier{}), http.MethodPost, "/api/v1/tasks", `{"unknown":true}`, "user-a|tasks.write")
	if response.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusBadRequest)
	}
}

func TestGetTaskRejectsInvalidUUID(t *testing.T) {
	t.Parallel()

	response := performRequest(t, New(testLogger(), fakeHealthChecker{}, &fakeTaskService{}, auth.DevVerifier{}), http.MethodGet, "/api/v1/tasks/not-a-uuid", "", "user-a|tasks.read")
	if response.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusBadRequest)
	}
}

func TestGetTaskReturnsNotFound(t *testing.T) {
	t.Parallel()

	response := performRequest(t, New(testLogger(), fakeHealthChecker{}, &fakeTaskService{}, auth.DevVerifier{}), http.MethodGet, "/api/v1/tasks/"+uuid.NewString(), "", "user-a|tasks.read")
	if response.Code != http.StatusNotFound {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusNotFound)
	}
}

func TestUpdateTaskCanClearDueAt(t *testing.T) {
	t.Parallel()

	service := &fakeTaskService{}
	response := performRequest(t, New(testLogger(), fakeHealthChecker{}, service, auth.DevVerifier{}), http.MethodPatch, "/api/v1/tasks/"+uuid.NewString(), `{"due_at":null}`, "user-a|tasks.write")
	if response.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d; body=%s", response.Code, http.StatusOK, response.Body.String())
	}
	if !service.updatedInput.DueAtSet || service.updatedInput.DueAt != nil {
		t.Fatalf("due_at clear was not preserved: %#v", service.updatedInput)
	}
}

func TestDeleteTask(t *testing.T) {
	t.Parallel()

	response := performRequest(t, New(testLogger(), fakeHealthChecker{}, &fakeTaskService{}, auth.DevVerifier{}), http.MethodDelete, "/api/v1/tasks/"+uuid.NewString(), "", "user-a|tasks.write")
	if response.Code != http.StatusNoContent {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusNoContent)
	}
}

func TestPanicIsRecovered(t *testing.T) {
	t.Parallel()

	response := performRequest(t, New(testLogger(), fakeHealthChecker{}, &fakeTaskService{listPanic: true}, auth.DevVerifier{}), http.MethodGet, "/api/v1/tasks", "", "user-a|tasks.read")
	if response.Code != http.StatusInternalServerError {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusInternalServerError)
	}
}

func performRequest(t *testing.T, handler http.Handler, method, path, body, token string) *httptest.ResponseRecorder {
	t.Helper()

	request := httptest.NewRequest(method, path, bytes.NewBufferString(body))
	if token != "" {
		request.Header.Set("Authorization", "Bearer "+token)
	}
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)
	return response
}

func testLogger() *slog.Logger {
	return slog.New(slog.NewJSONHandler(io.Discard, nil))
}
