/**
 * PM2 Ecosystem Configuration
 * 
 * Questo file configura PM2 per avviare il server MyTeam Video
 * 
 * Installazione PM2:
 *   npm install -g pm2
 * 
 * Comandi:
 *   pm2 start ecosystem.config.cjs
 *   pm2 stop myteam-video-server
 *   pm2 restart myteam-video-server
 *   pm2 logs myteam-video-server
 *   pm2 status
 *   pm2 save
 *   pm2 startup  # Configura avvio automatico
 */

module.exports = {
  apps: [
    {
      name: 'myteam-video-server',
      // Usa il path completo a python.exe nel venv
      // Su Windows, modifica questo path se necessario
      script: './venv/Scripts/python.exe',
      args: '-m uvicorn app.main:app --host 0.0.0.0 --port 8000 --timeout-keep-alive 300 --timeout-graceful-shutdown 30',
      cwd: './',
      interpreter: 'none', // PM2 userà direttamente l'eseguibile
      instances: 1,
      exec_mode: 'fork',
      
      // Environment variables
      env: {
        NODE_ENV: 'production',
        PYTHONUNBUFFERED: '1', // Disabilita buffering output Python
      },
      
      // Logging
      error_file: './logs/pm2-error.log',
      out_file: './logs/pm2-out.log',
      log_file: './logs/pm2-combined.log',
      time: true, // Aggiungi timestamp ai log
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
      merge_logs: true,
      
      // Auto restart
      autorestart: true,
      watch: false, // Disabilita watch mode in produzione
      max_memory_restart: '1G', // Riavvia se memoria supera 1GB
      
      // Restart policy
      min_uptime: '10s', // Considera stabile dopo 10 secondi
      max_restarts: 10, // Massimo 10 restart in 1 minuto
      restart_delay: 4000, // Attendi 4 secondi prima di riavviare
      
      // Advanced
      kill_timeout: 5000, // Timeout per kill graceful (5 secondi)
      wait_ready: false,
      listen_timeout: 10000,
      
      // Windows specific
      windowsHide: false,
    }
  ]
};

