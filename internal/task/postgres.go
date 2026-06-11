package task

import (
	"context"
	"errors"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type PostgresRepository struct {
	pool *pgxpool.Pool
}

func NewPostgresRepository(pool *pgxpool.Pool) *PostgresRepository {
	return &PostgresRepository{pool: pool}
}

func (r *PostgresRepository) List(ctx context.Context, ownerSub string) ([]Task, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT id, title, description, status, due_at, created_at, updated_at
		FROM tasks
		WHERE owner_sub = $1
		ORDER BY created_at DESC
	`, ownerSub)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	tasks := make([]Task, 0)
	for rows.Next() {
		var item Task
		if err := rows.Scan(&item.ID, &item.Title, &item.Description, &item.Status, &item.DueAt, &item.CreatedAt, &item.UpdatedAt); err != nil {
			return nil, err
		}
		tasks = append(tasks, item)
	}
	return tasks, rows.Err()
}

func (r *PostgresRepository) Create(ctx context.Context, ownerSub string, input CreateInput) (Task, error) {
	var item Task
	err := r.pool.QueryRow(ctx, `
		INSERT INTO tasks (owner_sub, title, description, due_at)
		VALUES ($1, $2, $3, $4)
		RETURNING id, title, description, status, due_at, created_at, updated_at
	`, ownerSub, input.Title, input.Description, input.DueAt).Scan(
		&item.ID, &item.Title, &item.Description, &item.Status, &item.DueAt, &item.CreatedAt, &item.UpdatedAt,
	)
	return item, err
}

func (r *PostgresRepository) Get(ctx context.Context, ownerSub string, id uuid.UUID) (Task, error) {
	var item Task
	err := r.pool.QueryRow(ctx, `
		SELECT id, title, description, status, due_at, created_at, updated_at
		FROM tasks
		WHERE id = $1 AND owner_sub = $2
	`, id, ownerSub).Scan(
		&item.ID, &item.Title, &item.Description, &item.Status, &item.DueAt, &item.CreatedAt, &item.UpdatedAt,
	)
	return item, mapNotFound(err)
}

func (r *PostgresRepository) Update(ctx context.Context, ownerSub string, id uuid.UUID, input UpdateInput) (Task, error) {
	var item Task
	err := r.pool.QueryRow(ctx, `
		UPDATE tasks
		SET
			title = COALESCE($3, title),
			description = COALESCE($4, description),
			status = COALESCE($5, status),
			due_at = CASE WHEN $6 THEN $7 ELSE due_at END,
			updated_at = NOW()
		WHERE id = $1 AND owner_sub = $2
		RETURNING id, title, description, status, due_at, created_at, updated_at
	`, id, ownerSub, input.Title, input.Description, input.Status, input.DueAtSet, input.DueAt).Scan(
		&item.ID, &item.Title, &item.Description, &item.Status, &item.DueAt, &item.CreatedAt, &item.UpdatedAt,
	)
	return item, mapNotFound(err)
}

func (r *PostgresRepository) Delete(ctx context.Context, ownerSub string, id uuid.UUID) error {
	tag, err := r.pool.Exec(ctx, `DELETE FROM tasks WHERE id = $1 AND owner_sub = $2`, id, ownerSub)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func mapNotFound(err error) error {
	if errors.Is(err, pgx.ErrNoRows) {
		return ErrNotFound
	}
	return err
}
