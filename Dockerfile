FROM mcr.microsoft.com/playwright:v1.58.2-noble

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci
RUN apt-get update \
    && apt-get install -y --no-install-recommends zip unzip openjdk-21-jre-headless \
    && rm -rf /var/lib/apt/lists/*

ENV SDKMAN_DIR=/root/.sdkman
ENV SDKMAN_NON_INTERACTIVE=true

SHELL ["/bin/bash", "-lc"]
RUN curl -s "https://get.sdkman.io" | bash \
    && source "${SDKMAN_DIR}/bin/sdkman-init.sh" \
    && sdk install ant \
    && sdk flush archives \
    && sdk flush temp

ENV ANT_HOME=/root/.sdkman/candidates/ant/current
ENV PATH="${ANT_HOME}/bin:${PATH}"

COPY . .

RUN npm run fetch:w3c
RUN npm run build:sef

ENV CI=1

CMD ["npm", "run", "test:e2e"]
