sudo docker build -t registry-v2.forcity.io/platform/internal_tools/devpi:4.7.1 devpi
sudo docker build -t registry-v2.forcity.io/platform/internal_tools/devpi_db:latest devpi_db

sudo docker push registry-v2.forcity.io/platform/internal_tools/devpi:4.7.1
sudo docker push registry-v2.forcity.io/platform/internal_tools/devpi_db:latest

