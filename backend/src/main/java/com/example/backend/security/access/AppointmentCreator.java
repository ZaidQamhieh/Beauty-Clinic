package com.example.backend.security.access;

import org.springframework.security.access.prepost.PreAuthorize;

import java.lang.annotation.Documented;
import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

// Every role books; that a patient books only for themselves is on a body field, so book checks it.
@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
@Documented
@PreAuthorize("hasAnyRole('DOCTOR', 'RECEPTIONIST', 'ADMIN', 'PATIENT')")
public @interface AppointmentCreator {
}
