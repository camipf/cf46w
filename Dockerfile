FROM ubuntu:latest
 
MAINTAINER Alper Kucukural <alper.kucukural@umassmed.edu>

RUN echo alper

RUN apt-get update
RUN apt-get -y upgrade
RUN apt-get dist-upgrade
 
# Install apache, PHP, and supplimentary programs. curl and lynx-cur are for debugging the container.
RUN DEBIAN_FRONTEND=noninteractive apt-get -y install apache2 libapache2-mod-php5 php5-mcrypt\
                    php5-mysqlnd php5-gd php-pear php-apc php5-curl curl lynx-cur mysql-server \
                    libreadline-dev libsqlite3-dev libbz2-dev libssl-dev python python-dev \
                    libmysqlclient-dev python-pip git expect default-jre r-base r-base-dev \
                    libxml2-dev software-properties-common libcurl4-gnutls-dev gdebi-core wget

RUN add-apt-repository ppa:marutter/rrutter

RUN apt-get update
RUN apt-get -y upgrade

RUN apt-get -y install r-base r-base-dev


RUN pip install MySQL-python

# Enable apache mods.
RUN a2enmod php5
RUN a2enmod rewrite


# Update the PHP.ini file, enable <? ?> tags and quieten logging.
RUN sed -i "s/short_open_tag = Off/short_open_tag = On/" /etc/php5/apache2/php.ini
RUN sed -i "s/error_reporting = .*$/error_reporting = E_ERROR | E_WARNING | E_PARSE/" /etc/php5/apache2/php.ini
 
# Manually set up the apache environment variables
ENV PATH=$PATH:/usr/local/bin/dolphin-bin
ENV APACHE_RUN_USER www-data
ENV APACHE_RUN_GROUP www-data
ENV APACHE_LOG_DIR /var/log/apache2
ENV APACHE_LOCK_DIR /var/lock/apache2
ENV APACHE_PID_FILE /var/run/apache2.pid
ENV DOLPHIN_PARAMS_SECTION=Docker


EXPOSE 80
EXPOSE 3306
EXPOSE 3838

#Install R Packages
RUN echo "r <- getOption('repos'); r['CRAN'] <- 'http://cran.us.r-project.org'; options(repos = r);" > ~/.Rprofile
RUN R -e 'install.packages(c("ggvis", "ggplot2", "RColorBrewer", "DT", "gplots", "data.table"), dependencies = TRUE )'
RUN R -e 'source("http://bioconductor.org/biocLite.R"); biocLite(c("DESeq2","GenomicRanges","IRanges","clusterProfiler","DESeq2","shiny","annotate","AnnotationDbi","org.Hs.eg.db","DOSE","edgeR","ReactomePA"));'
RUN R -e 'library(devtools); install_github("al2na/methylKit",build_vignettes=FALSE)'

# Update the default apache site with the config we created.
ADD apache-config.conf /etc/apache2/sites-enabled/000-default.conf

RUN echo "ServerName localhost" | sudo tee /etc/apache2/conf-available/fqdn.conf
RUN a2enconf fqdn
RUN echo "export DOLPHIN_PARAMS_SECTION="${DOLPHIN_PARAMS_SECTION} >> /etc/apache2/envvars

RUN mkdir -p /var/www/.java/.systemPrefs
RUN mkdir /var/www/.java/.userPrefs
RUN chmod -R 755 /var/www/.java
RUN chown -R ${APACHE_RUN_USER}:${APACHE_RUN_GROUP} /var/www
RUN echo "export JAVA_OPTS=\"-Djava.util.prefs.systemRoot=/var/www/.java Djava.util.prefs.userRoot=/var/www/.java/.userPrefs\"" >> /etc/apache2/envvars

RUN wget https://download3.rstudio.org/ubuntu-12.04/x86_64/shiny-server-1.4.2.786-amd64.deb
RUN gdebi -n shiny-server-1.4.2.786-amd64.deb
RUN rm shiny-server-1.4.2.786-amd64.deb

RUN pip install -U boto
RUN pip install numpy

# Install phpMyAdmin

RUN service mysql start \
    service apache2 start; \
    DEBIAN_FRONTEND=noninteractive apt-get -y install phpmyadmin; \ 
    zcat /usr/share/doc/phpmyadmin/examples/create_tables.sql.gz|mysql -uroot

RUN sed -i "s#// \$cfg\['Servers'\]\[\$i\]\['AllowNoPassword'\] = TRUE;#\$cfg\['Servers'\]\[\$i\]\['AllowNoPassword'\] = TRUE;#g" /etc/phpmyadmin/config.inc.php 
RUN ln -s /etc/phpmyadmin/apache.conf /etc/apache2/conf-enabled/phpmyadmin.conf
RUN php5enmod mcrypt

 
# Copy site into place.
ENV GITUSER=nephantes
ADD bin  /usr/local/bin
RUN git clone https://github.com/${GITUSER}/dolphin-bin /usr/local/bin/dolphin-bin
RUN cd /usr/local/bin/dolphin-bin/MACS-1.4.2 && python setup.py install
RUN cd /usr/local/bin/dolphin-bin/RSeQC-2.6.2 && python setup.py install
RUN git clone https://github.com/${GITUSER}/dolphin-tools /usr/local/share/dolphin_tools
RUN echo alper1
RUN git clone https://github.com/${GITUSER}/dolphin-ui.git /var/www/html/dolphin
RUN git clone https://github.com/${GITUSER}/debrowser.git /srv/shiny-server/debrowser
RUN R CMD INSTALL /srv/shiny-server/debrowser
RUN sed -i "s/#    library/     library/" /srv/shiny-server/debrowser/R/server.R
RUN mkdir -p /var/www/html/dolphin/tmp/files /var/www/html/dolphin/tmp/logs /export/tmp/logs
RUN chown -R ${APACHE_RUN_USER}:${APACHE_RUN_GROUP} /var/www/html/dolphin
RUN chown -R ${APACHE_RUN_USER}:${APACHE_RUN_GROUP} /usr/local/share/dolphin_tools

RUN apt-get -y autoremove

