# common/baseimage
FROM ubuntu:16.04
# this forces dpkg not to call sync() after package extraction and speeds up install
RUN echo "force-unsafe-io" > /etc/dpkg/dpkg.cfg.d/02apt-speedup
# we don't need and apt cache in a container
RUN echo "Acquire::http {No-Cache=True;};" > /etc/apt/apt.conf.d/no-cache

# common/postgis
RUN  export DEBIAN_FRONTEND=noninteractive
ENV  DEBIAN_FRONTEND noninteractive
RUN  dpkg-divert --local --rename --add /sbin/initctl
#RUN  ln -s /bin/true /sbin/initctl

# Use local cached debs from host (saves your bandwidth!)
# Change ip below to that of your apt-cacher-ng host
# Or comment this line out if you do not with to use caching
#ADD 71-apt-cacher-ng /etc/apt/apt.conf.d/71-apt-cacher-ng
# RUN echo "deb http://archive.ubuntu.com/ubuntu trusty main universe" > /etc/apt/sources.list
RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ xenial-pgdg main" > /etc/apt/sources.list.d/pgdg.list
RUN apt-get -y --fix-missing update && apt-get -yqq install ca-certificates rpl pwgen wget locales
RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
RUN locale-gen en_US && locale-gen en_US.UTF-8 && update-locale

#-------------Application Specific Stuff ----------------------------------------------------

# Next line a workaround for https://github.com/dotcloud/docker/issues/963
RUN apt-get -y --fix-missing update && apt-get install -y postgresql-9.6-postgis-2.3 postgresql-9.6-postgis-2.3-scripts openssh-client openssh-server rsync
RUN apt-get -y --fix-missing update && apt-get install -y sudo

# Start with supervisor
ADD custom /

# Open port 5432 so linked containers can see them
EXPOSE 5432

#ENV DATADIR /dbdata
# Run any additional tasks here that are too tedious to put in
# this dockerfile directly.
RUN chmod 0755 /opt/*sh
RUN chmod 0600 /etc/ssl/private/ssl-cert-snakeoil.key
USER postgres
RUN /opt/setup.sh

# We will run any commands in this when the container starts
USER root

# core/core_db
RUN wget http://artifacts.forcity.io/pgtune_0.9.3-2_all.deb -O /tmp/pgtune_0.9.3-2_all.deb && dpkg -i /tmp/pgtune_0.9.3-2_all.deb

RUN mkdir /dbtemplate && chown postgres.postgres /dbtemplate
RUN /opt/create_main_db.sh /dbtemplate devpi devpi devpi
RUN /opt/setup_access.sh -b /dbtemplate -d all -u devpi -a 0.0.0.0/0

CMD /opt/start.sh

