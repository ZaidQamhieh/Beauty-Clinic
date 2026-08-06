package com.example.backend.security;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.authorization.AuthorizationEventPublisher;
import org.springframework.security.authorization.SpringAuthorizationEventPublisher;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationConverter;
import org.springframework.security.oauth2.server.resource.authentication.JwtGrantedAuthoritiesConverter;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import com.example.backend.services.AccessTokenService;

import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.config.annotation.authentication.configuration.AuthenticationConfiguration;

import java.util.List;

@Configuration
@EnableMethodSecurity
// Activates and validates values under app.cors.
@EnableConfigurationProperties(CorsProperties.class)
class SecurityConfig {

    @Bean
    SecurityFilterChain filterChain(HttpSecurity http, CorsConfigurationSource corsConfigurationSource) throws Exception {
        return http
        // This REST API uses Bearer headers, not login cookies.
        .csrf(csrf -> csrf.disable())

        // Spring Security answers the browser's preflight here, before
        // authorization ever runs - without it, .anyRequest().authenticated()
        // rejects the token-less OPTIONS request with 401.
        .cors(cors -> cors.configurationSource(corsConfigurationSource))

        // Every request must carry its own access token.
        .sessionManagement(session -> session
                .sessionCreationPolicy(
                        SessionCreationPolicy.STATELESS
                )
        )

        .authorizeHttpRequests(auth -> auth
                .requestMatchers(
                        "/api/auth/login",
                        "/api/auth/refresh",
                        "/api/auth/logout"
                ).permitAll()
                // Deployment probes cannot carry a token.
                .requestMatchers("/actuator/health").permitAll()
                .anyRequest().authenticated()
        )

        // Read and validate Authorization: Bearer <JWT>.
        .oauth2ResourceServer(oauth2 -> oauth2
                .jwt(jwt -> jwt.jwtAuthenticationConverter(
                        jwtAuthenticationConverter()
                ))
        )
        .build();
    }

    // Named origins only: a wildcard on an API that reads Authorization would
    // let any site read a response if a browser ever sent credentials too.
    @Bean
    CorsConfigurationSource corsConfigurationSource(CorsProperties properties) {
        CorsConfiguration configuration = new CorsConfiguration();
        configuration.setAllowedOrigins(properties.allowedOrigins());
        configuration.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE"));
        configuration.setAllowedHeaders(List.of("Authorization", "Content-Type"));
        configuration.setAllowCredentials(false);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", configuration);
        return source;
    }

    private JwtAuthenticationConverter jwtAuthenticationConverter() {
        var authorities = new JwtGrantedAuthoritiesConverter();

        // Read ROLE_ADMIN, etc. from our JWT's authorities claim.
        authorities.setAuthoritiesClaimName(
                AccessTokenService.AUTHORITIES_CLAIM
        );

        // Values already contain ROLE_, so add no extra prefix.
        authorities.setAuthorityPrefix("");

        var converter = new JwtAuthenticationConverter();
        converter.setJwtGrantedAuthoritiesConverter(authorities);

        return converter;
    }

    @Bean
    AuthorizationEventPublisher authorizationEventPublisher(ApplicationEventPublisher publisher) {
        return new SpringAuthorizationEventPublisher(publisher);
    }

    // Exposed as a bean so AuthService can authenticate a login directly.
    @Bean
    AuthenticationManager authenticationManager(
            AuthenticationConfiguration configuration
    ) throws Exception {
        return configuration.getAuthenticationManager();
    }
}
