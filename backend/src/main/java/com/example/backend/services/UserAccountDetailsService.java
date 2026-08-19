package com.example.backend.services;

import com.example.backend.entities.UserAccount;
import com.example.backend.repositories.UserAccountRepository;
import com.example.backend.security.UserAccountDetails;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class UserAccountDetailsService implements UserDetailsService {

    private final UserAccountRepository users;

    @Override
    public UserAccountDetails loadUserByUsername(String email) {
        UserAccount account = users.findByEmailIgnoreCase(email)
                .orElseThrow(() -> new UsernameNotFoundException("No account for that email"));

        return UserAccountDetails.of(account);
    }
}
