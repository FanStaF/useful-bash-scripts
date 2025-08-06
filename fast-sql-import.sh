#!/bin/bash

# ---- Config ----
DEFAULT_DB_NAME="new_db"
OPTIMIZE_HEADER_MARKER="OPTIMIZATION HEADER INSERTED"
OPTIMIZE_FOOTER_MARKER="OPTIMIZATION FOOTER INSERTED"

QUIET=0
CREATE_DB_ONLY=0

# ---- Functions ----

print_help() {
  cat <<EOF
Usage: $(basename "$0") [sql_file] [options]

Options:
  --db <name>           Set the database name (default: $DEFAULT_DB_NAME)
  --create-db <name>    Create the given database (stays in menu)
  --quiet               Suppress output
  --help                Show this help message
EOF
}

prompt_for_file() {
  [[ $QUIET -eq 0 ]] && echo "📂 Select an SQL file (searching from ./)..."

  local selected_file
  selected_file=$(fzf --prompt="SQL file > " --preview="head -n 20 {}" --height=40% --layout=reverse --border)

  if [[ -z "$selected_file" ]]; then
    [[ $QUIET -eq 0 ]] && echo "❌ No file selected."
    return
  fi

  sql_file="$selected_file"
  [[ $QUIET -eq 0 ]] && echo "✅ Loaded file: $sql_file"

  if grep -qF "$OPTIMIZE_HEADER_MARKER" "$sql_file" 2>/dev/null; then
    [[ $QUIET -eq 0 ]] && echo "✅ Optimizations already present in file."
  else
    [[ $QUIET -eq 0 ]] && echo "⚠️  No optimizations found in file."
    read -p "➕ Do you want to add optimizations now? (y/n): " add_now
    if [[ "$add_now" =~ ^[Yy]$ ]]; then
      add_optimizations
    fi
  fi
}

add_optimizations() {
  [[ $QUIET -eq 0 ]] && echo "🔍 Checking for existing optimizations..."

  if grep -qF "$OPTIMIZE_HEADER_MARKER" "$sql_file" 2>/dev/null; then
    [[ $QUIET -eq 0 ]] && echo "⚠️  Optimizations already present. Skipping."
    return
  fi

  [[ $QUIET -eq 0 ]] && echo "✨ Adding optimizations to beginning and end of file..."

  temp_file=$(mktemp)

  {
    echo "-- $OPTIMIZE_HEADER_MARKER"
    echo "SET FOREIGN_KEY_CHECKS=0;"
    echo "SET UNIQUE_CHECKS=0;"
    echo "SET AUTOCOMMIT=0;"
    echo "DROP DATABASE IF EXISTS $db_name;"
    echo "CREATE DATABASE $db_name CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    echo "USE $db_name;"
  } > "$temp_file"

  cat "$sql_file" >> "$temp_file"

  {
    echo "-- $OPTIMIZE_FOOTER_MARKER"
    echo "COMMIT;"
    echo "SET FOREIGN_KEY_CHECKS=1;"
    echo "SET UNIQUE_CHECKS=1;"
    echo "SET AUTOCOMMIT=1;"
  } >> "$temp_file"

  mv "$temp_file" "$sql_file"

  [[ $QUIET -eq 0 ]] && echo "✅ Optimizations added to $sql_file."
}

remove_optimizations() {
  [[ $QUIET -eq 0 ]] && echo "🧹 Removing optimizations if present..."

  if ! grep -qF "$OPTIMIZE_HEADER_MARKER" "$sql_file"; then
    [[ $QUIET -eq 0 ]] && echo "⚠️  No optimizations found. Skipping."
    return
  fi

  temp_file=$(mktemp)
  sed -e "/$OPTIMIZE_HEADER_MARKER/,+6d" -e "/$OPTIMIZE_FOOTER_MARKER/,+3d" "$sql_file" > "$temp_file"
  mv "$temp_file" "$sql_file"

  [[ $QUIET -eq 0 ]] && echo "✅ Optimizations removed from $sql_file."
}

create_db() {
  read -p "👤 MySQL user: " MYSQL_USER
  read -sp "🔑 MySQL password: " MYSQL_PASS
  echo
  [[ $QUIET -eq 0 ]] && echo "🗃  Creating database '$db_name'..."

  mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "DROP DATABASE IF EXISTS $db_name; CREATE DATABASE $db_name CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" && \
  [[ $QUIET -eq 0 ]] && echo "✅ Database created." || echo "❌ Failed to create database."
}

import_sql() {
  read -p "👤 MySQL user: " MYSQL_USER
  read -sp "🔑 MySQL password: " MYSQL_PASS
  echo

  [[ $QUIET -eq 0 ]] && echo "🚀 Starting import of $sql_file into database $db_name..."
  start_time=$(date +%s)

  if mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" "$db_name" < "$sql_file"; then
    status="✅ Import completed successfully."
  else
    status="❌ Import failed."
  fi

  end_time=$(date +%s)
  duration=$((end_time - start_time))

  [[ $QUIET -eq 0 ]] && {
    echo
    echo "📊 Import Summary"
    echo "---------------------------"
    echo "$status"
    echo "🕐 Duration: ${duration}s ($(awk \"BEGIN {print $duration/60}\")) min)"
    echo "📄 File: $sql_file"
    echo "📦 Size: $(du -h \"$sql_file\" | cut -f1)"
    echo "🔢 Lines: $(wc -l < \"$sql_file\")"
    echo "---------------------------"
  }

  if grep -qF "$OPTIMIZE_HEADER_MARKER" "$sql_file" 2>/dev/null; then
    read -p "🧹 Do you want to remove the optimizations from the file? (y/n): " remove_now
    if [[ "$remove_now" =~ ^[Yy]$ ]]; then
      remove_optimizations
    fi
  fi
}

menu() {
  while true; do
    echo
    echo "========== MySQL Import Menu =========="
    echo "Current file: ${sql_file:-<none>}"
    echo "Target DB: $db_name"
    echo "----------------------------------------"
    echo "1. Load SQL file"
    echo "2. Add optimizations"
    echo "3. Remove optimizations"
    echo "4. Create database in MySQL"
    echo "5. Import SQL file into database"
    echo "6. Set database name manually"
    echo "7. Exit"
    echo "========================================"
    read -p "Choose an option: " choice

    case $choice in
      1) prompt_for_file ;;
      2) [[ -z "$sql_file" ]] && prompt_for_file; [[ -n "$sql_file" ]] && add_optimizations ;;
      3) [[ -z "$sql_file" ]] && prompt_for_file; [[ -n "$sql_file" ]] && remove_optimizations ;;
      4) create_db ;;
      5) [[ -z "$sql_file" ]] && prompt_for_file; [[ -n "$sql_file" ]] && import_sql ;;
      6) read -p "📝 Enter new database name: " new_db; [[ -n "$new_db" ]] && db_name="$new_db" && echo "✅ Database name set to: $db_name" ;;
      7) echo "👋 Goodbye!"; exit 0 ;;
      *) echo "❌ Invalid option" ;;
    esac
  done
}

# ---- Init ----

sql_file=""
db_name="$DEFAULT_DB_NAME"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help)
      print_help; exit 0 ;;
    --quiet)
      QUIET=1; shift ;;
    --create-db)
      CREATE_DB_ONLY=1; db_name="$2"; shift 2 ;;
    --db)
      db_name="$2"; shift 2 ;;
    *)
      [[ -z "$sql_file" ]] && sql_file="$1"
      shift ;;
  esac
done

# Run initial DB creation if flag passed
if [[ $CREATE_DB_ONLY -eq 1 ]]; then
  create_db
fi

# Start interactive menu
menu

# ---- Config ----
DEFAULT_DB_NAME="r20_dev6"
OPTIMIZE_HEADER_MARKER="OPTIMIZATION HEADER INSERTED"
OPTIMIZE_FOOTER_MARKER="OPTIMIZATION FOOTER INSERTED"

# ---- Functions ----

prompt_for_file() {
  echo "📂 Select an SQL file (searching from ./)..."
  
  local selected_file
  selected_file=$(fzf --prompt="SQL file > " --preview="head -n 20 {}" --height=40% --layout=reverse --border)

  if [[ -z "$selected_file" ]]; then
    echo "❌ No file selected."
    return
  fi

  sql_file="$selected_file"
  echo "✅ Loaded file: $sql_file"

  # Check for optimizations
  if grep -qF "$OPTIMIZE_HEADER_MARKER" "$sql_file" 2>/dev/null; then
    echo "✅ Optimizations already present in file."
  else
    echo "⚠️  No optimizations found in file."
    read -p "➕ Do you want to add optimizations now? (y/n): " add_now
    if [[ "$add_now" =~ ^[Yy]$ ]]; then
      add_optimizations
    fi
  fi
}


add_optimizations() {
  echo "🔍 Checking for existing optimizations..."

  if grep -qF "$OPTIMIZE_HEADER_MARKER" "$sql_file" 2>/dev/null; then
    echo "⚠️  Optimizations already present. Skipping."
    return
  fi

  echo "✨ Adding optimizations to beginning and end of file..."

  temp_file=$(mktemp)

  # Write header
  {
    echo "-- $OPTIMIZE_HEADER_MARKER"
    echo "SET FOREIGN_KEY_CHECKS=0;"
    echo "SET UNIQUE_CHECKS=0;"
    echo "SET AUTOCOMMIT=0;"
    echo "DROP DATABASE IF EXISTS $db_name;"
    echo "CREATE DATABASE $db_name CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    echo "USE $db_name;"
  } > "$temp_file"

  # Stream original SQL file into it (no memory spike)
  cat "$sql_file" >> "$temp_file"

  # Write footer
  {
    echo "-- $OPTIMIZE_FOOTER_MARKER"
    echo "COMMIT;"
    echo "SET FOREIGN_KEY_CHECKS=1;"
    echo "SET UNIQUE_CHECKS=1;"
    echo "SET AUTOCOMMIT=1;"
  } >> "$temp_file"

  mv "$temp_file" "$sql_file"

  echo "✅ Optimizations added to $sql_file."
}

remove_optimizations() {
  echo "🧹 Removing optimizations if present..."

  if ! grep -qF "$OPTIMIZE_HEADER_MARKER" "$sql_file"; then
    echo "⚠️  No optimizations found. Skipping."
    return
  fi

  temp_file=$(mktemp)

  # Remove 7 lines starting from header marker, and 4 from footer
  sed -e "/$OPTIMIZE_HEADER_MARKER/,+6d" -e "/$OPTIMIZE_FOOTER_MARKER/,+3d" "$sql_file" > "$temp_file"

  mv "$temp_file" "$sql_file"
  echo "✅ Optimizations removed from $sql_file."
}

create_db() {
  read -p "👤 MySQL user: " MYSQL_USER
  read -sp "🔑 MySQL password: " MYSQL_PASS
  echo
  echo "🗃  Creating database '$db_name'..."
  mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "DROP DATABASE IF EXISTS $db_name; CREATE DATABASE $db_name CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" && \
  echo "✅ Database created." || echo "❌ Failed to create database."
}

import_sql() {
  read -p "👤 MySQL user: " MYSQL_USER
  read -sp "🔑 MySQL password: " MYSQL_PASS
  echo

  echo "🚀 Starting import of $sql_file into database $db_name..."
  start_time=$(date +%s)

  if mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" "$db_name" < "$sql_file"; then
    status="✅ Import completed successfully."
  else
    status="❌ Import failed."
  fi

  end_time=$(date +%s)
  duration=$((end_time - start_time))

  echo
  echo "📊 Import Summary"
  echo "---------------------------"
  echo "$status"
  echo "🕐 Duration: ${duration}s ($(awk "BEGIN {print $duration/60}") min)"
  echo "📄 File: $sql_file"
  echo "📦 Size: $(du -h "$sql_file" | cut -f1)"
  echo "🔢 Lines: $(wc -l < "$sql_file")"
  echo "---------------------------"

   if grep -qF "$OPTIMIZE_HEADER_MARKER" "$sql_file" 2>/dev/null; then
    read -p "🧹 Do you want to remove the optimizations from the file? (y/n): " remove_now
    if [[ "$remove_now" =~ ^[Yy]$ ]]; then
      remove_optimizations
    fi
  fi
}

menu() {
  while true; do
    echo
    echo "========== MySQL Import Menu =========="
    echo "Current file: ${sql_file:-<none>}"
    echo "Target DB: $db_name"
    echo "----------------------------------------"
    echo "1. Load SQL file"
    echo "2. Add optimizations"
    echo "3. Remove optimizations"
    echo "4. Create database in MySQL"
    echo "5. Import SQL file into database"
    echo "6. Exit"
    echo "========================================"
    read -p "Choose an option: " choice

    case $choice in
      1)
        prompt_for_file
        ;;
      2)
        [[ -z "$sql_file" ]] && prompt_for_file
        [[ -n "$sql_file" ]] && add_optimizations
        ;;
      3)
        [[ -z "$sql_file" ]] && prompt_for_file
        [[ -n "$sql_file" ]] && remove_optimizations
        ;;
      4)
        create_db
        ;;
      5)
        [[ -z "$sql_file" ]] && prompt_for_file
        [[ -n "$sql_file" ]] && import_sql
        ;;
      6)
        echo "👋 Goodbye!"
        exit 0
        ;;
      *)
        echo "❌ Invalid option"
        ;;
    esac
  done
}

# ---- Init ----

sql_file="$1"
db_name="$DEFAULT_DB_NAME"

menu

