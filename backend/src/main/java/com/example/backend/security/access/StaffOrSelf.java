package com.example.backend.security.access;

import org.springframework.security.access.prepost.PreAuthorize;

import java.lang.annotation.Documented;
import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

// Needs a method parameter named id.
@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
@Documented
@PreAuthorize("hasAnyRole('DOCTOR', 'RECEPTIONIST', 'ADMIN') or @access.isSelf(#id)")
public @interface StaffOrSelf {
}
