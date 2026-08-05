# Authorization

What each role is allowed to do. This is the reference the `@PreAuthorize` rules are written against — if a rule and this document disagree, one of them is a bug.

## Roles

Exactly one role per account, held on `user_account.role`. A user is a patient or a receptionist or a doctor or an admin, never a combination. An owner who also treats patients has to pick one.

There is no separate staff record: a doctor is a `user_account` with role `DOCTOR`.

| Role | Who they are |
|---|---|
| `PATIENT` | Someone the clinic treats, using the app for themselves |
| `RECEPTIONIST` | Front desk: registers patients, manages the calendar |
| `DOCTOR` | Provides treatments, owns the clinical record |
| `ADMIN` | Runs the clinic and the system |

## PATIENT

- Log in, log out, stay signed in
- View own profile
- Edit own profile — non-clinical fields only
- Change own password
- Browse doctors, their working hours, and the services each one offers
- View the service list
- View own appointments, read-only
- Ask for a reschedule; the clinic cancels the booking and makes a new one
- Read own allergies and treatment notes, read-only
- View own notifications

Patients do not book their own appointments, do not cancel, and never write clinical data. Rescheduling is done by the clinic: the existing booking is cancelled and a replacement created.

## RECEPTIONIST

- Log in, log out, stay signed in
- View and edit own profile, change own password
- Register a new patient
- Search patients
- View and edit patient demographics
- See free slots
- Book, reschedule and cancel appointments
- View the whole clinic schedule and doctors' working hours
- Mark an appointment attended or no-show
- View the service list
- View own notifications

No clinical data at all: the front desk cannot read or write allergies or treatment notes.

## DOCTOR

- Log in, log out, stay signed in
- View and edit own profile, change own password
- Set own working hours
- Set which services they offer
- View own day schedule
- Register a new patient
- Search patients
- View and edit patient demographics
- View and edit allergies
- Write, read and amend treatment notes
- See free slots
- Book, reschedule and cancel appointments
- Mark an appointment attended or no-show
- View the service list
- View own notifications

## ADMIN

Everything the other three roles can do, plus:

- Create an account and assign its role
- Change someone's role
- Deactivate and reactivate an account
- Unlock an account locked by failed logins
- Reset someone's password
- Add, edit, enable and disable services
- View the activity log

## System

Not tied to any role — these run on a schedule or as a side effect, with no human caller:

- Appointment reminders
- Notifications when a booking is cancelled or replaced

## Ownership, not just role

Several operations are restricted to the caller's own data, so the role alone does not decide them. A patient may read their own treatment notes but not anyone else's; a doctor sets their own working hours, not another doctor's.

Own-scoped operations:

- View and edit own profile, change own password
- Set own working hours and own service list
- View own appointments, own day schedule, own notifications
- Read own allergies and treatment notes

These need the caller's account id. The access token carries a `uid` claim holding it, alongside `sub` for the email, and `CurrentUser` reads it back off the request.

## Field-level restrictions

Two operations are not all-or-nothing on a record:

- A patient editing their own profile may write name, phone, address and language preference, but not clinical fields. That has to be a separate request body rather than one endpoint that binds the whole row and checks a role inside.
- A receptionist may edit patient demographics but must not see allergies, so the patient representation they receive cannot carry clinical fields at all.

## Schema the policy rests on

- `doctor` — a doctor is a `user_account` with role `DOCTOR`; this row holds only what is specific to practising, including working hours as a `jsonb` array.
- `doctor_service` — which treatments each doctor offers, rather than all of them implicitly.
- `patient.allergies` — the clinical field reception never receives.
- `service.price` — the treatment menu.
- `appointment.replaces_appointment_id` — rescheduling cancels the old booking and creates a new one pointing back at it, rather than moving a row. There is no reschedule-request record: a patient asks off-system and the clinic rebooks.

## How the rules get written

An endpoint names its rule with an annotation rather than spelling out an expression, so the same check cannot be retyped slightly differently in two places:

```java
@GetMapping("/{id}/clinical")
@ClinicalReader
public PatientRecord readClinical(@PathVariable UUID id)
```

The tags live in `com.example.backend.security.access`.

Role only:

| Tag | Admits |
|---|---|
| `@AdminOnly` | admin |
| `@DoctorOnly` | doctor |
| `@ReceptionistOnly` | receptionist |
| `@PatientOnly` | patient |
| `@ClinicStaffOnly` | doctor, receptionist, admin |
| `@ClinicianOnly` | doctor, admin |
| `@Authenticated` | anyone signed in |

Role combined with ownership:

| Tag | Admits |
|---|---|
| `@StaffOrOwnPatient` | clinic staff, or the patient whose record it is |
| `@ClinicalReader` | admin, a doctor who has treated them, or the patient themselves |
| `@ClinicalWriter` | admin, or a doctor who has treated them |
| `@DoctorSelfOrAdmin` | admin, or the doctor whose own record it is |
| `@AppointmentReader` | clinic staff, or the patient it belongs to |

The three mixed tags reference `#id`, so they only work on a method with a parameter of that name. That fails closed: elsewhere the expression resolves to null, the rule returns false, and the caller gets 403.

The ownership half sits on `AccessRules`, registered as `access`:

- `ownsPatient(patientId)` — the patient record belonging to the caller's account
- `treats(patientId)` — the caller has an appointment with them
- `ownsAppointment(appointmentId)` — the appointment's patient is the caller's own record
- `isSelf(userId)` — the caller is that account

Each answers only "may this caller", never "does this exist". A missing row is `false` here and a 404 from the handler, so a probe cannot tell an id that exists from one that does not.

Rules are added alongside the endpoints that need them, with tests, rather than ahead of them.
