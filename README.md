# DockerFiles

This docker image is base on nvidia/cuda:11.0.3-cudnn8-devel-ubuntu18.04

## Build Dockerfile
```
 docker build -t [username]/[image_name]:[tag] .
```


## How to Create docker container
```
docker run -it -d -p 25911:5901 -p 26911:6901 -p 25910:22  -v [Local volume path]:/home/user/Desktop/data [username]/[image_name]:[tag]
```


# Enviroments
## 1. Ports
```
VNC_PORT="5901" 
NO_VNC_PORT="6901"
API_PORT1="5050"
API_PORT2="5055"
API_PORT3="8080"
API_PORT4="8088"
```
## 2. applications
```
google-chrome
atom
nomic (image viewer)
anaconda
```

### anaconda package (CUDA 11.0-specific steps)
```
Pillow
scikit-learn
matplotlib
pandas
scikit-image 
albumentations
opencv-python

conda install -y -c pytorch \
    cudatoolkit=11.0.221 \
    "pytorch=1.7.0=py3.8_cuda11.0.221_cudnn8.0.3_0" \
    "torchvision=0.8.1=py38_cu110"
```

