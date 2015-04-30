## Proftpd saim docker file
FROM phusion/baseimage

MAINTAINER Edwin Urquilla <edwin.urquilla@gmail.com>

# Set correct environment variables.
#ENV HOME /root
ENV DEBIAN_FRONTEND noninteractive

# Regenerate SSH host keys. baseimage-docker does not contain any, so you
# have to do that yourself. You may also comment out this instruction; the
# init system will auto-generate one during boot.
#RUN /etc/my_init.d/00_regen_ssh_host_keys.sh

# Use baseimage-docker's init system.
CMD ["/sbin/my_init"]

RUN rm -f /etc/service/sshd/down
RUN /usr/sbin/enable_insecure_key

# Prerequisites
RUN apt-get update && apt-get install -y \
    ssl-cert \
    postfix \
    dovecot-imapd \
    opendkim && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# postfix configuration
ADD ./config/postfix.main.cf /etc/postfix/main.cf
ADD ./config/postfix.master.cf.append /etc/postfix/master-additional.cf
RUN cat /etc/postfix/master-additional.cf >> /etc/postfix/master.cf

# configure settings script
VOLUME ["/mail_settings"]
COPY process_settings /process_settings
RUN chmod 755 /process_settings

# add user vmail who own all mail folders
VOLUME ["/vmail"]
RUN groupadd -g 5000 vmail
RUN useradd -g vmail -u 5000 vmail -d /vmail -m

# dovecot configuration
ADD ./config/dovecot.mail /etc/dovecot/conf.d/10-mail.conf
ADD ./config/dovecot.ssl /etc/dovecot/conf.d/10-ssl.conf
ADD ./config/dovecot.auth /etc/dovecot/conf.d/10-auth.conf
ADD ./config/dovecot.master /etc/dovecot/conf.d/10-master.conf
ADD ./config/dovecot.lda /etc/dovecot/conf.d/15-lda.conf
ADD ./config/dovecot.imap /etc/dovecot/conf.d/20-imap.conf
# add verbose logging
#ADD ./config/dovecot.logging /etc/dovecot/conf.d/10-logging.conf

EXPOSE 25 143 587
# todo: enable port 587 for outgoing mail, separate ports 25 and 587
# http://www.synology-wiki.de/index.php/Zusaetzliche_Ports_fuer_Postfix

# start necessary services for operation (dovecot -F starts dovecot in the foreground to prevent container exit)
ENTRYPOINT /process_settings; service rsyslog start; service opendkim start; service postfix start; dovecot -F
