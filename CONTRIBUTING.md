# Contributing Guidelines

## Git Workflow

### Branch Strategy

- `main`: Production-ready code
- `develop`: Integration branch for features
- `feature/*`: Feature branches (e.g., `feature/create-tables`)
- `fix/*`: Bug fix branches

### Commit Convention

Follow the format: `<type>(<scope>): <description>`

**Types:**

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Formatting, missing semicolons, etc.
- `refactor`: Code change that neither fixes a bug nor adds a feature
- `test`: Adding tests
- `chore`: Updating build tasks, package manager configs, etc.

**Examples:**

```bash
feat(db): create core tables with PK/FK constraints
feat(db): add ISA relationship for solo_artists and bands
feat(sp): implement revenue ROLLUP stored procedure
feat(app): add dashboard with revenue charts
docs(readme): update project structure documentation
fix(db): correct foreign key constraint on contracts table
```

### Workflow Steps

1. **Create feature branch from develop:**

   ```bash
   git checkout develop
   git pull origin develop
   git checkout -b feature/your-feature-name
   ```

2. **Make changes and commit:**

   ```bash
   git add .
   git commit -m "feat(db): create core tables"
   ```

3. **Push to remote:**

   ```bash
   git push origin feature/your-feature-name
   ```

4. **Create Pull Request:**
   - From `feature/your-feature-name` to `develop`
   - Request review from team members
   - Merge after approval

5. **Merge develop to main (for releases):**
   ```bash
   git checkout main
   git merge develop
   git push origin main
   ```

## Team Member Responsibilities

| Member | Role           | Responsibilities                                 |
| ------ | -------------- | ------------------------------------------------ |
| A      | DB Architect   | ERD design, data specification, requirements doc |
| B      | SQL Developer  | DDL scripts, seed data, views creation           |
| C      | Query Engineer | Stored procedures, data exploitation queries     |
| D      | Report & Demo  | Streamlit app, slides, final report, screenshots |

## File Naming Conventions

### SQL Files

- Migrations: `001_create_tables.sql`, `002_create_isa.sql`
- Seeds: `001_seed_labels.sql`, `002_seed_artists.sql`
- Procedures: `sp_revenue_rollup.sql`, `sp_revenue_pivot.sql`

### Documentation

- Use kebab-case: `thiet-ke-luan-ly.md`
- English alternatives: `logical-design.md`

### Screenshots

- Format: `sp1_revenue_rollup.png`, `dashboard_overview.png`
- Use descriptive names

## Code Standards

### SQL Style

- Keywords in UPPERCASE: `SELECT`, `FROM`, `WHERE`
- Table/column names in lowercase with underscores: `artist_id`, `revenue_logs`
- Indent nested queries
- Add comments for complex logic

### Python Style

- Follow PEP 8
- Use type hints where applicable
- Add docstrings to functions
- Keep functions small and focused

## Pull Request Guidelines

**PR Title Format:**

```
[TYPE] Brief description of changes
```

**PR Description Should Include:**

- What changes were made
- Why these changes were needed
- How to test the changes
- Screenshots (if applicable)

**Example:**

```
[FEAT] Add revenue ROLLUP stored procedure

Changes:
- Created sp_revenue_rollup.sql
- Implements GROUP BY ROLLUP for artist revenue by month
- Includes grand total calculation

Testing:
- Execute: SELECT * FROM sp_revenue_rollup();
- Verify output includes subtotals and grand totals
```

## Review Process

1. At least one team member must review and approve
2. All tests must pass (if applicable)
3. Code must follow style guidelines
4. Documentation must be updated if needed

## Questions?

Contact the team lead or open an issue in the repository.
