{ ... }:

{
  # Classic crontab. Jobs are not written here. Agents and users add them with
  # the `schedules` CLI (home/schedules), which owns the user crontab and takes
  # effect at once, with no rebuild.
  services.cron.enable = true;

  # schedules can run a job inside a detached tmux session. That session lives
  # under /run/user/<uid>, which systemd deletes at logout unless the user
  # lingers. Linger keeps the tmux server, and therefore those jobs, alive.
  users.users.wesbragagt.linger = true;
}
