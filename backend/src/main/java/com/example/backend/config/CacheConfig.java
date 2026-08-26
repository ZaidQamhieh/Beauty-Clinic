package com.example.backend.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.jsontype.BasicPolymorphicTypeValidator;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import lombok.extern.slf4j.Slf4j;
import org.springframework.cache.Cache;
import org.springframework.cache.CacheManager;
import org.springframework.cache.annotation.CachingConfigurer;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.cache.interceptor.CacheErrorHandler;
import org.springframework.cache.support.NoOpCacheManager;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.Ordered;
import org.springframework.data.redis.cache.RedisCacheConfiguration;
import org.springframework.data.redis.cache.RedisCacheManager;
import org.springframework.data.redis.connection.RedisConnection;
import org.springframework.data.redis.connection.RedisConnectionFactory;
import org.springframework.data.redis.serializer.GenericJackson2JsonRedisSerializer;
import org.springframework.data.redis.serializer.RedisSerializationContext;

import java.time.Duration;
import java.util.Map;

// Ordered first; a hit opens no transaction.
@Configuration
@EnableCaching(order = Ordered.HIGHEST_PRECEDENCE)
@Slf4j
public class CacheConfig implements CachingConfigurer {

    private static final Duration DEFAULT_TTL = Duration.ofMinutes(5);

    // Booking and cancelling evict this explicitly.
    private static final Duration ANALYTICS_TTL = Duration.ofMinutes(5);

    // Clinical/PII data; short TTL bounds staleness.
    private static final Duration PATIENT_DATA_TTL = Duration.ofSeconds(30);


    @Value("${app.cache.redis.enabled:true}")
    private boolean redisCacheEnabled;

    @Bean
    public CacheManager cacheManager(ObjectProvider<RedisConnectionFactory> connectionFactories) {
        RedisConnectionFactory connectionFactory = connectionFactories.getIfAvailable();

        if (!redisCacheEnabled) {
            log.info("Redis cache switched off; running uncached");
            return new NoOpCacheManager();
        }
        if (connectionFactory == null || !reachable(connectionFactory)) {
            log.warn("Redis not reachable; running uncached");
            return new NoOpCacheManager();
        }

        // NON_FINAL drops root-record type tags.
        ObjectMapper mapper = new ObjectMapper()
                .registerModule(new JavaTimeModule())
                .activateDefaultTyping(
                        BasicPolymorphicTypeValidator.builder()
                                .allowIfBaseType(Object.class)
                                .build(),
                        ObjectMapper.DefaultTyping.EVERYTHING);

        var serializer = RedisSerializationContext.SerializationPair
                .fromSerializer(new GenericJackson2JsonRedisSerializer(mapper));

        RedisCacheConfiguration defaultConfig = RedisCacheConfiguration.defaultCacheConfig()
                .entryTtl(DEFAULT_TTL)
                .serializeValuesWith(serializer);

        RedisCacheConfiguration analyticsConfig = RedisCacheConfiguration.defaultCacheConfig()
                .entryTtl(ANALYTICS_TTL)
                .serializeValuesWith(serializer);

        RedisCacheConfiguration patientDataConfig = RedisCacheConfiguration.defaultCacheConfig()
                .entryTtl(PATIENT_DATA_TTL)
                .serializeValuesWith(serializer);

        return RedisCacheManager.builder(connectionFactory)
                .cacheDefaults(defaultConfig)
                .withInitialCacheConfigurations(Map.of(
                        "dashboardAnalytics", analyticsConfig,
                        "patientData", patientDataConfig))
                .build();
    }

    // One ping; dev machines may lack Redis.
    private boolean reachable(RedisConnectionFactory connectionFactory) {
        try (RedisConnection connection = connectionFactory.getConnection()) {
            connection.ping();
            return true;
        } catch (RuntimeException e) {
            log.debug("Redis ping failed: {}", e.getMessage());
            return false;
        }
    }

    // Honoured via CachingConfigurer, not a bean.
    @Bean
    @Override
    public CacheErrorHandler errorHandler() {
        return new CacheErrorHandler() {
            @Override
            public void handleCacheGetError(RuntimeException e, Cache cache, Object key) {
                log.warn("Cache read failed for {}: {}", cache.getName(), e.getMessage());
            }

            @Override
            public void handleCachePutError(RuntimeException e, Cache cache, Object key, Object value) {
                log.warn("Cache write failed for {}: {}", cache.getName(), e.getMessage());
            }

            @Override
            public void handleCacheEvictError(RuntimeException e, Cache cache, Object key) {
                log.warn("Cache evict failed for {}: {}", cache.getName(), e.getMessage());
            }

            @Override
            public void handleCacheClearError(RuntimeException e, Cache cache) {
                log.warn("Cache clear failed for {}: {}", cache.getName(), e.getMessage());
            }
        };
    }
}
