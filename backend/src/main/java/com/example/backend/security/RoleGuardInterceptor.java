package com.example.backend.security;

import com.example.backend.exception.RoleDeniedException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.annotation.AnnotatedElementUtils;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.method.HandlerMethod;
import org.springframework.web.servlet.HandlerInterceptor;

import java.util.HashSet;
import java.util.Set;

public class RoleGuardInterceptor implements HandlerInterceptor {

    private static final Logger log = LoggerFactory.getLogger(RoleGuardInterceptor.class);

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
        if (!(handler instanceof HandlerMethod handlerMethod)) {
            return true;
        }

        RequireRole requireRole = AnnotatedElementUtils.findMergedAnnotation(handlerMethod.getMethod(), RequireRole.class);
        if (requireRole == null) {
            requireRole = AnnotatedElementUtils.findMergedAnnotation(handlerMethod.getBeanType(), RequireRole.class);
            if (requireRole == null) {
                return true;
            }
        }

        Set<Role> required = Set.of(requireRole.value());
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();

        Set<String> grantedRoleNames = new HashSet<>();
        if (authentication != null) {
            for (GrantedAuthority authority : authentication.getAuthorities()) {
                grantedRoleNames.add(authority.getAuthority());
            }
        }

        boolean hasRequiredRole = false;
        for (Role role : required) {
            if (grantedRoleNames.contains(role.name())) {
                hasRequiredRole = true;
                break;
            }
        }

        if (!hasRequiredRole) {
            String principal = "anonymous";
            if (authentication != null) {
                principal = authentication.getName();
            }
            log.warn("Access denied: principal={} path={} requiredRoles={}", principal, request.getRequestURI(), required);
            throw new RoleDeniedException(required);
        }

        return true;
    }
}
