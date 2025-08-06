### `fast-sql-import.sh`

Optimizes and simplifies the process of importing large `.sql` files.

- Applies temporary MySQL performance tweaks (e.g., disables foreign key checks, increases buffer sizes)
- Presents a menu to select an `.sql` file and target database
- Supports `.sql` files compressed with `.gz`
- Restores original MySQL settings after import

**Use case:** When you frequently import large MySQL dumps for development or testing and want a faster, safer workflow.

---

### `run-pipeline.sh`

A developer-focused pipeline runner for PHP projects.

- Menu-based selection of actions to perform
- Launches a Docker environment (with PHP, Composer, etc.)
- Runs tools like:
  - [Pest](https://pestphp.com/) — testing framework
  - [PHPStan](https://phpstan.org/) — static analysis
- Designed to be flexible and extensible for local or CI-like usage

**Use case:** Quickly spin up a test/analysis pipeline on any Git repository without installing PHP or dependencies locally.

---

## 📦 Requirements

- Bash 5.x+
- `docker` (for `run-pipeline.sh`)
- `mysql` CLI (for `fast-sql-import.sh`)
- `pv` and `gzip` (optional but recommended for import progress)

---

## 🚀 Usage

Clone this repo and make scripts executable:

```bash
git clone git@github.com:FanStaF/useful-bash-scripts.git
cd useful-bash-scripts
chmod +x *.sh
