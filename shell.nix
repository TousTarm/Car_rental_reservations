# Development environment for NixOS: Ruby + a project-local MySQL server.
# Usage: `nix-shell`, then `bin/rails ...` as usual. Nothing is installed system-wide.
{ pkgs ? import <nixpkgs> { } }:

pkgs.mkShell {
  packages = with pkgs; [
    ruby_3_4
    mysql84 # server, client and mysql_config (needed to compile the mysql2 gem)
    # Native extensions of Rails default gems compile against these.
    pkg-config
    gcc
    gnumake
    openssl
    zlib
    zstd
    libyaml
    libffi
  ];

  shellHook = ''
    # Gems go to the home directory, because the Nix store is read-only.
    export GEM_HOME="$HOME/.local/share/gem/ruby/3.4"
    export PATH="$GEM_HOME/bin:$PATH"

    # MySQL data live in tmp/mysql, which Rails' .gitignore already ignores.
    export MYSQL_DATADIR="$PWD/tmp/mysql"
    if [ ! -d "$MYSQL_DATADIR" ]; then
      mkdir -p "$PWD/tmp"
      # Local dev only: root without a password, listening on 127.0.0.1.
      mysqld --initialize-insecure --datadir="$MYSQL_DATADIR" > "$PWD/tmp/mysql-init.log" 2>&1
    fi
    if ! mysqladmin --host=127.0.0.1 --user=root ping > /dev/null 2>&1; then
      mysqld --datadir="$MYSQL_DATADIR" --bind-address=127.0.0.1 --port=3306 \
        --socket="$PWD/tmp/mysql.sock" --pid-file="$PWD/tmp/mysql.pid" --mysqlx=OFF \
        > "$PWD/tmp/mysql.log" 2>&1 &
      echo "MySQL started on 127.0.0.1:3306 (stop it with: mysqladmin -h 127.0.0.1 -u root shutdown)"
    fi
  '';
}
