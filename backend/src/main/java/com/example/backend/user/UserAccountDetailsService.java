package com.example.backend.user;

import com.example.backend.security.Role;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
class UserAccountDetailsService implements UserDetailsService {

    private final UserAccountRepository users;

    @Override
    public UserDetails loadUserByUsername(String email) {
        UserAccount account = users.findByEmailIgnoreCase(email)
                .orElseThrow(() -> new UsernameNotFoundException("No account for that email"));

        return User.withUsername(account.getEmail())
                .password(account.getPasswordHash())
                .authorities(account.getRoles().stream().map(Role::authority).toList())
                .disabled(!account.isEnabled())
                .build();
    }
}
