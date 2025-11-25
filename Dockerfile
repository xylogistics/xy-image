FROM node:22-alpine
RUN apk add --no-cache tini && mkdir -p /usr/src/app
WORKDIR /usr/src
COPY ./package.json ./package-lock.json /usr/src/
RUN npm ci --omit=dev && npm cache clean --force
WORKDIR /usr/src/app
COPY ./ /usr/src/app/
ENV NODE_ENV production
ENV NODE_PATH ./:../node_modules
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["npm", "run", "start"]
