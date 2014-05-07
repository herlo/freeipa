FROM herlo/fedora:20
RUN yum -y install sssd; yum clean all; systemctl enable sssd.service
CMD ["/usr/sbin/init"]
