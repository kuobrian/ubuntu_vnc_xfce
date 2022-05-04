# DockerFiles


Build Dockerfile
```
 docker build -t kuobrian614/ubuntu_vnc_xfce:lastest .
```


Create docker container
```
docker run -it -d -p 25911:5901 -p 26911:6901 -p 25910:22  -v /home/brian/data:/home/user/Desktop/data kuobrian614/ubuntu_vnc_xfce:lastest
```
