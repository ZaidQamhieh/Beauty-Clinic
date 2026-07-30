package com.example.backend.exception;

import com.example.backend.security.Role;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.web.ErrorResponseException;

import java.util.Set;

public class RoleDeniedException extends ErrorResponseException {

    public RoleDeniedException(Set<Role> requiredRoles) {
        super(HttpStatus.FORBIDDEN, problemDetail(requiredRoles), null);
    }

    private static ProblemDetail problemDetail(Set<Role> requiredRoles) {
        ProblemDetail problem = ProblemDetail.forStatus(HttpStatus.FORBIDDEN);
        problem.setTitle("Access Denied");
        problem.setDetail("You do not have permission to access this resource");
        problem.setProperty("requiredRoles", requiredRoles);
        return problem;
    }
}
