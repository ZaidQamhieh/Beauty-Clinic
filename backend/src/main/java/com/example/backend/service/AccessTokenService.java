package com.example.backend.service;

import lombok.RequiredArgsConstructor;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;
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

/*
  Creates short-lived access tokens after a user's email and
  password have already been verified.
 */
@Service
@RequiredArgsConstructor
public class AccessTokenService {

    /*
      SecurityConfig will later use the same claim name when it
      converts JWT data back into Spring Security authorities.
     */
    public static final String AUTHORITIES_CLAIM = "authorities";

    // Id of the refresh-token row this session belongs to. See SessionTokenValidator.
    public static final String SESSION_CLAIM = "sid";

    /*
      JwtEncoder comes from JwtConfig.
      It performs the actual JWT signing using our HMAC secret.
     */
    private final JwtEncoder jwtEncoder;

    /*
      Contains the configured issuer and access-token lifetime.
     */
    private final TokenProperties properties;

    /*
      Generate an access token for an authenticated user.
     
      This method must only be called after Spring Security has
      successfully verified the user's email and password.
     */
    public IssuedAccessToken issue(UserDetails user, UUID sessionId) {
        // Record when the token was created.
        Instant issuedAt = Instant.now();

        // Calculate when it becomes invalid: now + 15 minutes by default.
        Instant expiresAt = issuedAt.plus(properties.accessTtl());

        /*
          Convert Spring Security authorities into strings.
         
          Example:
          [ROLE_PATIENT, ROLE_ADMIN]
         
          These values will later restore the user's RBAC permissions
          without querying PostgreSQL on every request.
         */
        List<String> authorities = user.getAuthorities().stream()
                .map(GrantedAuthority::getAuthority)
                .sorted()
                .toList();

        /*
          Claims make up the JWT payload.
         
          JWT payloads are readable, not encrypted, so passwords and
          other secrets must never be placed here.
         */
        JwtClaimsSet claims = JwtClaimsSet.builder()
                // Identifies the backend that created the token.
                .issuer(properties.issuer())

                // Identifies the user. In this project, it's their email.
                .subject(user.getUsername())

                // Standard JWT creation timestamp: "iat".
                .issuedAt(issuedAt)

                // Standard JWT expiration timestamp: "exp".
                .expiresAt(expiresAt)

                // Unique token identifier: "jti".
                .id(UUID.randomUUID().toString())

                // Custom claim containing the user's RBAC authorities.
                .claim(AUTHORITIES_CLAIM, authorities)

                // Identifies which refresh-token session issued this token.
                .claim(SESSION_CLAIM, sessionId.toString())
                .build();

        /*
          The JWT header describes how the token is signed.
         
          HS256 means HMAC using SHA-256.
          "JWT" describes the token's type.
         */
        JwsHeader header = JwsHeader.with(MacAlgorithm.HS256)
                .type("JWT")
                .build();

        /*
          Nimbus combines the header and claims, signs them with the
          secret key and produces:
         
          header.payload.signature
         */
        String value = jwtEncoder.encode(
                JwtEncoderParameters.from(header, claims)
        ).getTokenValue();

        /*
          Return both the token and its lifetime.
          The controller will later include these in TokenResponse.
         */
        return new IssuedAccessToken(
                value,
                properties.accessTtl().toSeconds()
        );
    }

    /*
      Immutable result produced when an access token is created.
     */
    public record IssuedAccessToken(
            String value,
            long expiresInSeconds
    ) {
    }
}
