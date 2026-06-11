package task

import (
	"context"
	"errors"
	"testing"

	"github.com/google/uuid"
)

type fakeRepository struct {
	createdOwner string
	createdInput CreateInput
}

func (f *fakeRepository) List(context.Context, string) ([]Task, error) {
	return nil, nil
}

func (f *fakeRepository) Create(_ context.Context, ownerSub string, input CreateInput) (Task, error) {
	f.createdOwner = ownerSub
	f.createdInput = input
	return Task{ID: uuid.New(), Title: input.Title, Description: input.Description, Status: StatusTodo}, nil
}

func (f *fakeRepository) Get(context.Context, string, uuid.UUID) (Task, error) {
	return Task{}, nil
}

func (f *fakeRepository) Update(context.Context, string, uuid.UUID, UpdateInput) (Task, error) {
	return Task{}, nil
}

func (f *fakeRepository) Delete(context.Context, string, uuid.UUID) error {
	return nil
}

func TestServiceCreateNormalizesInput(t *testing.T) {
	t.Parallel()

	repository := &fakeRepository{}
	service := NewService(repository)

	_, err := service.Create(context.Background(), "user-a", CreateInput{
		Title:       "  learn Go  ",
		Description: "  understand interfaces  ",
	})
	if err != nil {
		t.Fatalf("Create returned error: %v", err)
	}
	if repository.createdOwner != "user-a" {
		t.Fatalf("owner = %q, want user-a", repository.createdOwner)
	}
	if repository.createdInput.Title != "learn Go" || repository.createdInput.Description != "understand interfaces" {
		t.Fatalf("input was not normalized: %#v", repository.createdInput)
	}
}

func TestServiceRejectsEmptyTitle(t *testing.T) {
	t.Parallel()

	service := NewService(&fakeRepository{})
	_, err := service.Create(context.Background(), "user-a", CreateInput{Title: "   "})
	if !errors.Is(err, ErrValidation) {
		t.Fatalf("Create error = %v, want ErrValidation", err)
	}
}

func TestServiceRejectsEmptyUpdate(t *testing.T) {
	t.Parallel()

	service := NewService(&fakeRepository{})
	_, err := service.Update(context.Background(), "user-a", uuid.New(), UpdateInput{})
	if !errors.Is(err, ErrValidation) {
		t.Fatalf("Update error = %v, want ErrValidation", err)
	}
}
