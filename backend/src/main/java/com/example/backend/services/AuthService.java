package com.example.backend.services;

import com.example.backend.dtos.LoginRequest;
import com.example.backend.dtos.RefreshTokenRequest;
import com.example.backend.dtos.RegisterRequest;
import com.example.backend.dtos.TokenResponse;

import com.example.backend.entities.PatientProfile;
import com.example.backend.entities.UserAccount;
import com.example.backend.security.Role;
import com.example.backend.security.UserAccountDetails;
import com.example.backend.repositories.PatientProfileRepository;
import com.example.backend.repositories.UserAccountRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.security.authentication.DisabledException;
import org.springframework.security.authentication.LockedException;
import java.util.Locale;

@Service
@RequiredArgsConstructor
public class AuthService {

    private final AuthenticationManager authenticationManager;
    private final UserAccountRepository users;
    private final PatientProfileRepository patientProfiles;
    private final PasswordEncoder passwordEncoder;
    private final AccessTokenService accessTokens;
    private final RefreshTokenService refreshTokens;
    private final UserAccountDetailsService userDetailsService;
    private final LoginLockoutService lockouts;
    private final ActivityLogService activityLogs;

    @Transactional
    public TokenResponse register(RegisterRequest request) {
        // One answer for both, so the endpoint never confirms a phone number outright.
        boolean taken = users.findByEmailIgnoreCase(request.email()).isPresent()
                || (request.phone() != null && users.existsByPhone(request.phone()));

        if (taken) {
            throw new ResponseStatusException(
                    HttpStatus.CONFLICT, "An account with those details already exists");
        }

        // Role is fixed here, never read from the body: self-registration cannot mint staff.
        UserAccount account = new UserAccount(
                request.email(), null, request.firstName(), request.lastName(), Role.PATIENT
        );
        account.setPhone(request.phone());
        account.setDateOfBirth(request.dateOfBirth());
        account.setGender(request.gender());

        // The only path that may set a password, so user_account_credentials always holds.
        account.activateWith(passwordEncoder.encode(request.password()));
        users.save(account);

        patientProfiles.save(new PatientProfile(account));
        activityLogs.recordRegistration(account.getId());

        UserAccountDetails principal = UserAccountDetails.of(account);
        var refreshToken = refreshTokens.issue(account);
        var accessToken = accessTokens.issue(principal, refreshToken.sessionId());

        return new TokenResponse(
                accessToken.value(),
                refreshToken.value(),
                "Bearer",
                accessToken.expiresInSeconds(),
                principal.getRole().name()
        );
    }

    @Transactional
    public TokenResponse login(LoginRequest request) {

        String attemptedIdentifier = request.email();

        String identifier = attemptedIdentifier
                .trim()
                .toLowerCase(Locale.ROOT);

        Authentication authentication;

        try {
                lockouts.assertNotLocked(identifier);

                var credentials = UsernamePasswordAuthenticationToken
                        .unauthenticated(
                                identifier,
                                request.password()
                        );

                authentication =
                        authenticationManager.authenticate(credentials);

        } catch (AuthenticationException failure) {

                if (countsAsGuess(failure)) {
                        lockouts.recordFailure(identifier);
                }

                activityLogs.recordFailedLogin(
                        attemptedIdentifier
                );

                throw failure;
        }

        lockouts.recordSuccess(identifier);

        UserAccountDetails principal =
                (UserAccountDetails) authentication.getPrincipal();

        UserAccount user = users
                .findById(principal.getUserId())
                .orElseThrow(() -> new UsernameNotFoundException(
                        "Authenticated user no longer exists"
                ));

        var refreshToken = refreshTokens.issue(user);

        var accessToken = accessTokens.issue(
                principal,
                refreshToken.sessionId()
        );

        activityLogs.recordLogin(user.getId());

        return new TokenResponse(
                accessToken.value(),
                refreshToken.value(),
                "Bearer",
                accessToken.expiresInSeconds(),
                principal.getRole().name()
      );
    }

    // Locked, unclaimed and disabled are not password guesses.
    private boolean countsAsGuess(AuthenticationException failure) {
        return !(failure instanceof LockedException)
                && !(failure instanceof DisabledException);
    }

    @Transactional
    public TokenResponse refresh(RefreshTokenRequest request) {
        var rotatedToken = refreshTokens.rotate(
                request.refreshToken()
        );

        lockouts.assertNotLocked(rotatedToken.email());

        UserAccountDetails principal = userDetailsService.loadUserByUsername(
                rotatedToken.email()
        );

        if (!principal.isEnabled()) {
            throw new DisabledException("Account is disabled");
        }

        var accessToken = accessTokens.issue(principal, rotatedToken.sessionId());

        // Reloaded from the account, so a role changed mid-session reaches the client here.
        return new TokenResponse(
                accessToken.value(),
                rotatedToken.value(),
                "Bearer",
                accessToken.expiresInSeconds(),
                principal.getRole().name()
        );
    }

    public void logout(RefreshTokenRequest request) {
        refreshTokens.logout(request.refreshToken());
    }
}
