FROM nvidia/cuda:11.0.3-cudnn8-devel-ubuntu18.04 as stage-ubuntu

### 'apt-get clean' runs automatically
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-key del 7fa2af80
RUN rm /etc/apt/sources.list.d/cuda.list
RUN rm /etc/apt/sources.list.d/nvidia-ml.list
RUN rm -rf /var/lib/apt/lists/*


RUN apt-get update \
    && apt-get install -y lsb-release net-tools unzip vim zip curl git wget \
			ca-certificates apt-transport-https gnupg gnupg2 software-properties-common \
        		libjpeg-dev libpng-dev iputils-ping net-tools libgl1 libglib2.0-0 tree \
        		nginx gettext-base ibus-sunpinyin pybind11-dev libssl-dev libprotobuf-dev protobuf-compiler

RUN apt-get install sudo
RUN rm -rf /var/lib/apt/lists/*

RUN wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/cuda-keyring_1.0-1_all.deb \
    && dpkg -i cuda-keyring_1.0-1_all.deb

### next ENTRYPOINT command supports development and should be overriden or disabled
### it allows running detached containers created from intermediate images, for example:
### docker build --target stage-vnc -t dev/ubuntu-vnc-xfce:stage-vnc .
### docker run -d --name test-stage-vnc dev/ubuntu-vnc-xfce:stage-vnc
### docker exec -it test-stage-vnc bash
# ENTRYPOINT ["tail", "-f", "/dev/null"]

FROM stage-ubuntu as stage-xfce

ENV \
    LANG='en_US.UTF-8' \
    LANGUAGE='en_US:en' \
    LC_ALL='en_US.UTF-8'

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update 
RUN apt-get install -y mousepad supervisor xfce4 xfce4-terminal
RUN apt-get install -y locales 
RUN locale-gen en_US.UTF-8
RUN apt-get purge -y pm-utils xscreensaver* 

# RUN rm -rf /var/lib/apt/lists/*

FROM stage-xfce as stage-vnc

### 'apt-get clean' runs automatically
### installed into '/usr/share/usr/local/share/vnc'
### Bintray has been deprecated and disabled since 2021-05-01 
# RUN wget -qO- https://dl.bintray.com/tigervnc/stable/tigervnc-1.10.1.x86_64.tar.gz | tar xz --strip 1 -C /
# RUN wget -qO- https://github.com/accetto/tigervnc/releases/download/v1.10.1-mirror/tigervnc-1.10.1.x86_64.tar.gz | tar xz --strip 1 -C /
RUN wget -qO- https://github.com/kuobrian/ubuntu_vnc_xfce/releases/download/v1.10.1-mirror/tigervnc-1.10.1.x86_64.1.tar.gz |  tar  xz --strip 1 -C /



FROM stage-vnc as stage-novnc

### same parent path as VNC
ENV NO_VNC_HOME=/usr/share/usr/local/share/noVNCdim

### 'apt-get clean' runs automatically
### 'python-numpy' used for websockify/novnc
### ## Use the older version of websockify to prevent hanging connections on offline containers, 
### see https://github.com/ConSol/docker-headless-vnc-container/issues/50
### installed into '/usr/share/usr/local/share/noVNCdim'
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get install -y python-numpy \
    && mkdir -p ${NO_VNC_HOME}/utils/websockify \
    && wget -qO- https://github.com/novnc/noVNC/archive/v1.2.0.tar.gz | tar xz --strip 1 -C ${NO_VNC_HOME} \
    && wget -qO- https://github.com/novnc/websockify/archive/v0.9.0.tar.gz | tar xz --strip 1 -C ${NO_VNC_HOME}/utils/websockify \
    && chmod +x -v ${NO_VNC_HOME}/utils/*.sh 

### add 'index.html' for choosing noVNC client
RUN echo \
"<!DOCTYPE html>\n" \
"<html>\n" \
"    <head>\n" \
"        <title>noVNC</title>\n" \
"        <meta charset=\"utf-8\"/>\n" \
"    </head>\n" \
"    <body>\n" \
"        <p><a href=\"vnc_lite.html\">noVNC Lite Client</a></p>\n" \
"        <p><a href=\"vnc.html\">noVNC Full Client</a></p>\n" \
"    </body>\n" \
"</html>" \
> ${NO_VNC_HOME}/index.html

FROM stage-novnc as stage-wrapper

### 'apt-get clean' runs automatically
### Install nss-wrapper to be able to execute image as non-root user

RUN apt-get update 
ENV DEBIAN_FRONTEND=noninteractive 
RUN apt-get install -y gettext libnss-wrapper 

RUN apt-get install -y terminator

#dbus
RUN mkdir -p /var/run/dbus
RUN chown messagebus:messagebus /var/run/dbus
RUN dbus-uuidgen --ensure

FROM stage-wrapper as stage-final

# Create a non-root user and switch to it
ARG USERNAME=user
ARG USERID=1000

RUN useradd --create-home -s /bin/bash --no-user-group -u $USERID $USERNAME \
    && adduser $USERNAME sudo \
    && echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

### Arguments can be provided during build
ARG ARG_HOME
ARG ARG_REFRESHED_AT
ARG ARG_VERSION_STICKER
ARG ARG_VNC_BLACKLIST_THRESHOLD
ARG ARG_VNC_BLACKLIST_TIMEOUT
ARG ARG_VNC_PW
ARG ARG_VNC_RESOLUTION

ENV \
    DISPLAY=:1 \
    HOME=${ARG_HOME:-/home/user} \
    NO_VNC_PORT="6901" \
    REFRESHED_AT=${ARG_REFRESHED_AT} \
    STARTUPDIR=/dockerstartup \
    VERSION_STICKER=${ARG_VERSION_STICKER} \
    VNC_BLACKLIST_THRESHOLD=${ARG_VNC_BLACKLIST_THRESHOLD:-20} \
    VNC_BLACKLIST_TIMEOUT=${ARG_VNC_BLACKLIST_TIMEOUT:-0} \
    VNC_COL_DEPTH=24 \
    VNC_PORT="5901" \
    API_PORT1="5050" \
    API_PORT2="5055" \
    API_PORT3="8080" \
    API_PORT4="8088" \
    VNC_PW=${ARG_VNC_PW:-123456} \
    VNC_RESOLUTION=${ARG_VNC_RESOLUTION:-1980x1200} \
    VNC_VIEW_ONLY=false

### Creates home folder
WORKDIR ${HOME}

COPY [ "./src/startup", "${STARTUPDIR}/" ]

### Preconfigure Xfce
COPY [ "./src/home/Desktop", "./Desktop/" ]
COPY [ "./src/home/config/xfce4/panel", "./.config/xfce4/panel/" ]
COPY [ "./src/home/config/xfce4/xfconf/xfce-perchannel-xml", "./.config/xfce4/xfconf/xfce-perchannel-xml/" ]

### 'generate_container_user' has to be sourced to hold all env vars correctly
RUN echo 'source $STARTUPDIR/generate_container_user' >> ${HOME}/.bashrc

# install google-chrome && install manually all the missing libraries
RUN apt-get update
RUN apt-get install -y gconf-service libasound2 libatk1.0-0 libcairo2 libcups2 libfontconfig1 libgdk-pixbuf2.0-0 libgtk-3-0 libnspr4 \
		libpango-1.0-0 libxss1 fonts-liberation libappindicator1 libnss3 lsb-release xdg-utils libgbm1
RUN wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
RUN dpkg -i google-chrome-stable_current_amd64.deb; apt-get -fy install

# instal Atom Editer
RUN wget -qO - https://packagecloud.io/AtomEditor/atom/gpgkey | sudo apt-key add -
RUN sh -c 'echo "deb [arch=amd64] https://packagecloud.io/AtomEditor/atom/any/ any main" > /etc/apt/sources.list.d/atom.list'
RUN apt-get update
RUN apt-get install atom -y

RUN echo "alias atom='atom --no-sandbox'" >> ${HOME}/.bashrc
RUN echo "alias chrome='google-chrome --no-sandbox'" >> ${HOME}/.bashrc

# install Image Viewer
RUN apt-get install nomacs -y

### Fix permissions
RUN chmod +x \
        "${STARTUPDIR}/set_user_permissions.sh" \
        "${STARTUPDIR}/vnc_startup.sh" \
        "${STARTUPDIR}/version_of.sh" \
        "${STARTUPDIR}/version_sticker.sh" \
    && gtk-update-icon-cache -f /usr/share/icons/hicolor \
    && "${STARTUPDIR}"/set_user_permissions.sh "${STARTUPDIR}" "${HOME}"    

EXPOSE ${VNC_PORT} ${NO_VNC_PORT}

EXPOSE ${API_PORT1} ${API_PORT2} ${API_PORT3} ${API_PORT4}

EXPOSE 22

# WORKDIR ${STARTUPDIR}
# RUN ./vnc_startup.sh

USER $USERNAME

# Install Miniconda and Python 3.8
ENV CONDA_AUTO_UPDATE_CONDA=false
ENV PATH=/home/user/miniconda/bin:$PATH
RUN curl -sLo ~/miniconda.sh https://repo.continuum.io/miniconda/Miniconda3-py38_4.8.3-Linux-x86_64.sh \
    && chmod +x ~/miniconda.sh \
    && ~/miniconda.sh -b -p ~/miniconda \
    && rm ~/miniconda.sh \
    && conda install -y python==3.8.0

#RUN conda install -y -c Pillow scikit-learn matplotlib pandas scikit-image
 
#RUN pip install -U albumentations --no-binary imgaug
#RUN pip install opencv-python
 
# CUDA 11.0-specific steps
# RUN conda install -y -c pytorch \
#     cudatoolkit=11.0.221 \
#     "pytorch=1.7.0=py3.8_cuda11.0.221_cudnn8.0.3_0" \
#     "torchvision=0.8.1=py38_cu110" 
# RUN conda clean -ya
#  
#USER root
### Issue #7: Mitigating problems with foreground mode
WORKDIR ${STARTUPDIR}
ENTRYPOINT ["./vnc_startup.sh"]
CMD [ "--wait" ]

