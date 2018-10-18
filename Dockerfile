# An incomplete base Docker image for running JupyterHub
#
# Add your configuration to create a complete derivative Docker image.
#
# Include your configuration settings by starting with one of two options:
#
# Option 1:
#
# FROM jupyterhub/jupyterhub:latest
#
# And put your configuration file jupyterhub_config.py in /srv/jupyterhub/jupyterhub_config.py.
#
# Option 2:
#
# Or you can create your jupyterhub config and database on the host machine, and mount it with:
#
# docker run -v $PWD:/srv/jupyterhub -t jupyterhub/jupyterhub
#
# NOTE
# If you base on jupyterhub/jupyterhub-onbuild
# your jupyterhub_config.py will be added automatically
# from your docker directory.

FROM ubuntu:18.04
LABEL maintainer="Jupyter Project <jupyter@googlegroups.com>"

ENV DEBIAN_FRONTEND noninteractive
RUN apt-get -y update && \
    apt-get -y upgrade && \
    apt-get -y install texlive-xetex pandoc vim htop  wget git bzip2 swi-prolog locate sudo  && \
    apt-get purge && \
    apt-get clean #&& \
ENV LANG C.UTF-8

#ldap && user
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y libnss-ldap libpam-ldap ldap-utils nscd
COPY config/ldap.conf /etc/ldap.conf
COPY config/nsswitch.conf /etc/nsswitch.conf
RUN echo "session optional			pam_systemd.so" >> /etc/pam.d/common-session

# Setup local account for Admin user and return a random password
# Enforce password change at first login
#RUN PASSWORD=$(date +%s|sha256sum|base64|head -c 16)
#RUN echo 'pass for user max:' $PASSWORD
#RUN useradd max 
#RUN echo $PASSWORD 
# RUN echo -e "$PASSWORD\n$PASSWORD\n" | sudo passwd max
#RUN echo -e  "max:$PASSWORD" | chpasswd
#RUN chage -d 0 max
#COPY skel /etc/skel

# install Python + NodeJS with conda
RUN wget -q https://repo.continuum.io/miniconda/Miniconda3-4.5.1-Linux-x86_64.sh -O /tmp/miniconda.sh  && \
    echo '0c28787e3126238df24c5d4858bd0744 */tmp/miniconda.sh' | md5sum -c - && \
    bash /tmp/miniconda.sh -f -b -p /opt/conda && \
    /opt/conda/bin/conda install --yes -c conda-forge \
      python=3.6 sqlalchemy tornado jinja2 traitlets requests pip pycurl \
      nodejs configurable-http-proxy && \
    /opt/conda/bin/pip install --upgrade pip&& \
    /opt/conda/bin/pip install --upgrade prompt-toolkit backports.tempfile nbgrader notebook matplotlib numpy scipy opencv-python seaborn pandas  pandas-summary  scikit-image  imageio  sklearn&& \
    rm /tmp/miniconda.sh
ENV PATH=/opt/conda/bin:$PATH

ADD . /src/jupyterhub
WORKDIR /src/jupyterhub


RUN jupyter nbextension install --sys-prefix --py nbgrader --overwrite
RUN jupyter nbextension enable --sys-prefix --py nbgrader
RUN jupyter serverextension enable --sys-prefix --py nbgrader
RUN pip install . && \
    rm -rf $PWD ~/.cache ~/.npm

RUN mkdir -p /srv/jupyterhub/
RUN mkdir -p /etc/jupyter/
RUN mkdir -p /opt/conda/share/jupyter/kernels/swi/temp
RUN mkdir -p /srv/nbgrader/exchange
RUN chmod -Rv 777 /srv/nbgrader/exchange
RUN chmod -Rv 777 /opt/conda/share/jupyter/kernels/swi/temp
COPY swi/kernel.json /opt/conda/share/jupyter/kernels/swi/
COPY swi/swipl_kernel.py /opt/conda/share/jupyter/kernels/swi/
COPY config/jupyterhub_config.py /srv/jupyterhub/ 
COPY ssl_cert/key.pem /srv/jupyterhub/ 
COPY ssl_cert/cert.pem /srv/jupyterhub/ 
COPY config/nbgrader_config.py /etc/jupyter/

WORKDIR /srv/jupyterhub/
EXPOSE 8000

LABEL org.jupyter.service="jupyterhub"

CMD ["jupyterhub"]
