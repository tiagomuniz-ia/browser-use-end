#!/bin/bash
set -e

# Iniciar D-Bus system-wide (requereria root, então iniciamos o session bus)
# Tentativa de iniciar o D-Bus session bus
if [ -f /usr/bin/dbus-daemon ]; then
  export DBUS_SESSION_BUS_ADDRESS="unix:path=/tmp/dbus-session-bus-$(id -u)"
  # Criar o diretório se não existir (como usuário não-root)
  mkdir -p "$(dirname "${DBUS_SESSION_BUS_ADDRESS#unix:path=}")"
  dbus-daemon --session --address="${DBUS_SESSION_BUS_ADDRESS}" --nofork --nopidfile --syslog-only &
  DBUS_PID=$!
  echo "D-Bus session bus started with PID $DBUS_PID"
  # Dar um tempo para o D-Bus iniciar
  sleep 2
else
  echo "dbus-daemon not found, skipping D-Bus session start."
fi

# Iniciar Xvfb. O -nolisten tcp é por segurança.
# O DISPLAY já deve estar setado via ENV no Dockerfile
Xvfb "${DISPLAY}" -screen 0 1920x1080x24 -nolisten tcp +extension GLX +render -noreset &
XVFB_PID=$!
echo "Xvfb started with PID $XVFB_PID and DISPLAY ${DISPLAY}"
# Dar um tempo para o Xvfb iniciar
sleep 2

# Função para limpar os processos ao sair
cleanup() {
    echo "Cleaning up..."
    if [ -n "$XVFB_PID" ]; then
        kill "$XVFB_PID"
        wait "$XVFB_PID" 2>/dev/null || true
        echo "Xvfb stopped."
    fi
    if [ -n "$DBUS_PID" ]; then
        kill "$DBUS_PID"
        wait "$DBUS_PID" 2>/dev/null || true
        echo "D-Bus stopped."
    fi
    # Remover o socket D-Bus se existir
    if [ -n "$DBUS_SESSION_BUS_ADDRESS" ]; then
        rm -f "${DBUS_SESSION_BUS_ADDRESS#unix:path=}"
        echo "D-Bus socket removed."
    fi
}

# Trap para chamar a função cleanup ao sair
trap cleanup SIGINT SIGTERM EXIT

# Executa o comando principal (sua aplicação)
echo "Starting Uvicorn server..."
exec uvicorn api:app --host 0.0.0.0 --port 8000
