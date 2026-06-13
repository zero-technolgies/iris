package main

import (
	"errors"
	"fmt"
	"io"
	"os"
	"strconv"

	"github.com/golang-migrate/migrate/v4"
	_ "github.com/golang-migrate/migrate/v4/database/postgres"
	_ "github.com/golang-migrate/migrate/v4/source/file"
)

const defaultMigrationsPath = "file://migrations"

type config struct {
	DatabaseURL    string
	MigrationsPath string
}

func main() {
	if err := run(os.Args[1:], os.Getenv, os.Stdout); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func run(args []string, getenv func(string) string, out io.Writer) error {
	cfg, err := loadConfig(getenv)
	if err != nil {
		return err
	}

	command := "up"
	if len(args) > 0 {
		command = args[0]
	}

	migrator, err := migrate.New(cfg.MigrationsPath, cfg.DatabaseURL)
	if err != nil {
		return fmt.Errorf("creating migrator: %w", err)
	}
	defer closeMigrator(migrator)

	switch command {
	case "up":
		if err := migrator.Up(); err != nil && !errors.Is(err, migrate.ErrNoChange) {
			return fmt.Errorf("applying migrations: %w", err)
		}
		fmt.Fprintln(out, "migrations up to date")
	case "down":
		steps, err := parseDownSteps(args)
		if err != nil {
			return err
		}
		if err := migrator.Steps(-steps); err != nil && !errors.Is(err, migrate.ErrNoChange) {
			return fmt.Errorf("rolling back migrations: %w", err)
		}
		fmt.Fprintf(out, "rolled back %d migration(s)\n", steps)
	case "force":
		version, err := parseForceVersion(args)
		if err != nil {
			return err
		}
		if err := migrator.Force(version); err != nil {
			return fmt.Errorf("forcing migration version: %w", err)
		}
		fmt.Fprintf(out, "forced migration version %d\n", version)
	case "version":
		version, dirty, err := migrator.Version()
		if errors.Is(err, migrate.ErrNilVersion) {
			fmt.Fprintln(out, "version: none dirty: false")
			return nil
		}
		if err != nil {
			return fmt.Errorf("reading migration version: %w", err)
		}
		fmt.Fprintf(out, "version: %d dirty: %t\n", version, dirty)
	default:
		return fmt.Errorf("unknown command %q: use up, down <steps>, force <version>, or version", command)
	}

	return nil
}

func loadConfig(getenv func(string) string) (config, error) {
	databaseURL := getenv("DATABASE_URL")
	if databaseURL == "" {
		return config{}, fmt.Errorf("DATABASE_URL is required")
	}

	migrationsPath := getenv("MIGRATIONS_PATH")
	if migrationsPath == "" {
		migrationsPath = defaultMigrationsPath
	}

	return config{
		DatabaseURL:    databaseURL,
		MigrationsPath: migrationsPath,
	}, nil
}

func parseDownSteps(args []string) (int, error) {
	if len(args) != 2 {
		return 0, fmt.Errorf("down requires a positive step count")
	}

	steps, err := strconv.Atoi(args[1])
	if err != nil || steps < 1 {
		return 0, fmt.Errorf("down requires a positive step count")
	}

	return steps, nil
}

func parseForceVersion(args []string) (int, error) {
	if len(args) != 2 {
		return 0, fmt.Errorf("force requires a migration version")
	}

	version, err := strconv.Atoi(args[1])
	if err != nil || version < 0 {
		return 0, fmt.Errorf("force requires a non-negative migration version")
	}

	return version, nil
}

func closeMigrator(migrator *migrate.Migrate) {
	sourceErr, databaseErr := migrator.Close()
	if sourceErr != nil {
		fmt.Fprintln(os.Stderr, sourceErr)
	}
	if databaseErr != nil {
		fmt.Fprintln(os.Stderr, databaseErr)
	}
}
