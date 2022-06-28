FROM ubuntu:18.04

# Install dependencies
RUN apt-get update && \
 apt-get -y install apache2

# Install apache and write hello world message
COPY index.html /var/www/html/index.html
#RUN echo 'Hello World!' > /var/www/html/index.html

# Configure apache
RUN echo '. /etc/apache2/envvars' > /root/run_apache.sh && \
 echo 'mkdir -p /var/run/apache2' >> /root/run_apache.sh && \
 echo 'mkdir -p /var/lock/apache2' >> /root/run_apache.sh && \
 echo 'service apache2 reload' >> /root/run_apache.sh && \
 echo '/usr/sbin/apache2 -D FOREGROUND' >> /root/run_apache.sh 
RUN echo "ServerName localhost" | tee /etc/apache2/conf-available/servername.conf 
RUN a2enconf servername 
RUN chmod 777 /root/run_apache.sh

EXPOSE 80

CMD /root/run_apache.sh