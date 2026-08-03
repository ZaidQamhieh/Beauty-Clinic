package com.example.backend.security;

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
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.config.annotation.authentication.configuration.AuthenticationConfiguration;

@Configuration
@EnableMethodSecurity
class SecurityConfig {

    @Bean
    SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        return http
        // This REST API uses Bearer headers, not login cookies.
        .csrf(csrf -> csrf.disable())

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

    @Bean // AuthenticationManager coordinates credential verification and returns an authenticated user.
    AuthenticationManager authenticationManager(
            AuthenticationConfiguration configuration//gives us the manager Spring assembled from existing security components.
    ) throws Exception {
        // Spring builds this manager using the existing
        // UserAccountDetailsService and PasswordEncoder.
        return configuration.getAuthenticationManager();
    }
}
