# First stage of multi-stage build
# Installs Meteor and builds node.js version
# This stage is named 'builder'
# The data for this intermediary image is not included
# in the final image.
FROM node:8.10.0-slim as builder

RUN apt-get update && apt-get install -y \
	curl \
	g++ \
	git \
	build-essential

# Create a non-root user
RUN useradd -ms /bin/bash user
USER user
RUN mkdir /home/user/Viewers
COPY OHIFViewer/package.json /home/user/Viewers/OHIFViewer/
#ADD --chown=user:user . /home/user/Viewers
ADD . /home/user/Viewers
RUN chown user:user /home/user/Viewers

COPY ./meteor_install.sh ./meteor_install.sh
COPY ./ca-certificates.crt ./ca-certificates.crt
ENV CAFILE=/ca-certificates.crt
RUN cat ./meteor_install.sh | sh

# This does not work in the GE firewall
#RUN curl "https://install.meteor.com/?release=1.7.0.3" | sh
#RUN curl https://install.meteor.com/ | sh

RUN ls -ls /home/user/.meteor

WORKDIR /home/user/Viewers/OHIFViewer

ENV METEOR_PACKAGE_DIRS=../Packages
#ENV METEOR_SETTINGS="$(cat ../config/edisonDICOMWeb.json)"
ENV METEOR_PROFILE=1

#RUN npm install
RUN mkdir /home/user/app

# Permissions issue with meteor files when running the build.
USER root
RUN chown -R user:user /home/user/Viewers/OHIFViewer/.meteor
RUN chown -R user:user /home/user/Viewers/Packages
USER user

RUN /home/user/.meteor/meteor build --directory /home/user/app
WORKDIR /home/user/app/bundle/programs/server
RUN npm install --production

# Second stage of multi-stage build
# Creates a slim production image for the node.js application
FROM node:8.10.0-slim

RUN npm install -g pm2

WORKDIR /app
COPY --from=builder /home/user/app .
COPY dockersupport/app.json .

ENV ROOT_URL http://localhost:3000
ENV PORT 3000
ENV NODE_ENV production

EXPOSE 3000

CMD ["pm2-runtime", "app.json"]
