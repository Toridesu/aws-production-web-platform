package task

import (
	"errors"
	"strings"
	"time"

	"github.com/google/uuid"
)

var (
	ErrNotFound   = errors.New("task not found")
	ErrValidation = errors.New("validation error")
)

type Status string

const (
	StatusTodo       Status = "todo"
	StatusInProgress Status = "in_progress"
	StatusDone       Status = "done"
)

type Task struct {
	ID          uuid.UUID  `json:"id"`
	Title       string     `json:"title"`
	Description string     `json:"description"`
	Status      Status     `json:"status"`
	DueAt       *time.Time `json:"due_at"`
	CreatedAt   time.Time  `json:"created_at"`
	UpdatedAt   time.Time  `json:"updated_at"`
}

type CreateInput struct {
	Title       string
	Description string
	DueAt       *time.Time
}

type UpdateInput struct {
	Title       *string
	Description *string
	Status      *Status
	DueAt       *time.Time
	DueAtSet    bool
}

func (input *CreateInput) NormalizeAndValidate() error {
	input.Title = strings.TrimSpace(input.Title)
	input.Description = strings.TrimSpace(input.Description)
	if input.Title == "" || len(input.Title) > 200 {
		return ErrValidation
	}
	return nil
}

func (input *UpdateInput) NormalizeAndValidate() error {
	if input.Title != nil {
		value := strings.TrimSpace(*input.Title)
		input.Title = &value
		if value == "" || len(value) > 200 {
			return ErrValidation
		}
	}
	if input.Description != nil {
		value := strings.TrimSpace(*input.Description)
		input.Description = &value
	}
	if input.Status != nil && !input.Status.Valid() {
		return ErrValidation
	}
	if input.Title == nil && input.Description == nil && input.Status == nil && !input.DueAtSet {
		return ErrValidation
	}
	return nil
}

func (status Status) Valid() bool {
	switch status {
	case StatusTodo, StatusInProgress, StatusDone:
		return true
	default:
		return false
	}
}
