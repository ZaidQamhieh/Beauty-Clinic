package com.example.backend.service;

import lombok.RequiredArgsConstructor;
import org.springframework.security.core.GrantedAuthority;
import com.example.backend.user.UserAccountDetails;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.stereotype.Service;

import com.example.backend.security.TokenProperties;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class AccessTokenService {

    public static final String AUTHORITIES_CLAIM = "authorities";

    public static final String SESSION_CLAIM = "sid";

    public static final String USER_ID_CLAIM = "uid";

    private final JwtEncoder jwtEncoder;

    private final TokenProperties properties;

    public IssuedAccessToken issue(UserAccountDetails user, UUID sessionId) {
        Instant issuedAt = Instant.now();

        Instant expiresAt = issuedAt.plus(properties.accessTtl());

        List<String> authorities = user.getAuthorities().stream()
                .map(GrantedAuthority::getAuthority)
                .sorted()
                .toList();

        JwtClaimsSet claims = JwtClaimsSet.builder()
                .issuer(properties.issuer())

                .subject(user.getUsername())

                .issuedAt(issuedAt)

                .expiresAt(expiresAt)

                .id(UUID.randomUUID().toString())

                .claim(AUTHORITIES_CLAIM, authorities)

                .claim(SESSION_CLAIM, sessionId.toString())

                .claim(USER_ID_CLAIM, user.getUserId().toString())
                .build();

        JwsHeader header = JwsHeader.with(MacAlgorithm.HS256)
                .type("JWT")
                .build();

        String value = jwtEncoder.encode(
                JwtEncoderParameters.from(header, claims)
        ).getTokenValue();

        return new IssuedAccessToken(
                value,
                properties.accessTtl().toSeconds()
        );
    }

    public record IssuedAccessToken(
            String value,
            long expiresInSeconds
    ) {
    }
}
