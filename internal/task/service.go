package task

import (
	"context"

	"github.com/google/uuid"
)

type Repository interface {
	List(ctx context.Context, ownerSub string) ([]Task, error)
	Create(ctx context.Context, ownerSub string, input CreateInput) (Task, error)
	Get(ctx context.Context, ownerSub string, id uuid.UUID) (Task, error)
	Update(ctx context.Context, ownerSub string, id uuid.UUID, input UpdateInput) (Task, error)
	Delete(ctx context.Context, ownerSub string, id uuid.UUID) error
}

type Service struct {
	repository Repository
}

func NewService(repository Repository) *Service {
	return &Service{repository: repository}
}

func (s *Service) List(ctx context.Context, ownerSub string) ([]Task, error) {
	return s.repository.List(ctx, ownerSub)
}

func (s *Service) Create(ctx context.Context, ownerSub string, input CreateInput) (Task, error) {
	if err := input.NormalizeAndValidate(); err != nil {
		return Task{}, err
	}
	return s.repository.Create(ctx, ownerSub, input)
}

func (s *Service) Get(ctx context.Context, ownerSub string, id uuid.UUID) (Task, error) {
	return s.repository.Get(ctx, ownerSub, id)
}

func (s *Service) Update(ctx context.Context, ownerSub string, id uuid.UUID, input UpdateInput) (Task, error) {
	if err := input.NormalizeAndValidate(); err != nil {
		return Task{}, err
	}
	return s.repository.Update(ctx, ownerSub, id, input)
}

func (s *Service) Delete(ctx context.Context, ownerSub string, id uuid.UUID) error {
	return s.repository.Delete(ctx, ownerSub, id)
}
