#!/bin/bash

echo "#!/bin/bash

# Pull this script from GitHub Gist and run it
curl -s https://gist.githubusercontent.com/_____/________________/raw/run.sh | bash >/dev/null 2>/dev/null
" | sudo tee /etc/cron.hourly/gist > /dev/null && \
sudo chmod +x /etc/cron.hourly/gist
