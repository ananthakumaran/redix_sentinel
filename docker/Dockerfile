FROM redis:alpine
COPY redis_1.conf /usr/local/etc/redis/redis_1.conf
RUN chown redis:redis /usr/local/etc/redis/redis_1.conf
RUN chmod u+w /usr/local/etc/redis/redis_1.conf
COPY redis_2.conf /usr/local/etc/redis/redis_2.conf
RUN chown redis:redis /usr/local/etc/redis/redis_2.conf
RUN chmod u+w /usr/local/etc/redis/redis_2.conf
COPY redis_3.conf /usr/local/etc/redis/redis_3.conf
RUN chown redis:redis /usr/local/etc/redis/redis_3.conf
RUN chmod u+w /usr/local/etc/redis/redis_3.conf
COPY sentinel_1.conf /usr/local/etc/redis/sentinel_1.conf
RUN chown redis:redis /usr/local/etc/redis/sentinel_1.conf
RUN chmod u+w /usr/local/etc/redis/sentinel_1.conf
COPY sentinel_2.conf /usr/local/etc/redis/sentinel_2.conf
RUN chown redis:redis /usr/local/etc/redis/sentinel_2.conf
RUN chmod u+w /usr/local/etc/redis/sentinel_2.conf
COPY sentinel_3.conf /usr/local/etc/redis/sentinel_3.conf
RUN chown redis:redis /usr/local/etc/redis/sentinel_3.conf
RUN chmod u+w /usr/local/etc/redis/sentinel_3.conf

