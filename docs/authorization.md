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
- Request a reschedule, which notifies the doctor
- Read own allergies and treatment notes, read-only
- View own notifications

Patients do not book their own appointments, do not cancel, and never write clinical data. A reschedule request changes nothing on its own — the appointment moves only when a doctor acts on it.

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
- Act on reschedule requests for their own appointments
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
- Reschedule-request notifications

## Ownership, not just role

Several operations are restricted to the caller's own data, so the role alone does not decide them. A patient may read their own treatment notes but not anyone else's; a doctor sets their own working hours, not another doctor's.

Own-scoped operations:

- View and edit own profile, change own password
- Set own working hours and own service list
- View own appointments, own day schedule, own notifications
- Read own allergies and treatment notes
- Request a reschedule on own appointment
- Act on a reschedule request for own appointment

These need the caller's account id. The access token currently carries `sub` (the email) and no id, so every ownership check would mean a lookup by email per request. Adding a `uid` claim and a principal that exposes it is the first piece of work here, before any guard is written.

## Field-level restrictions

Two operations are not all-or-nothing on a record:

- A patient editing their own profile may write name, phone, address and language preference, but not clinical fields. That has to be a separate request body rather than one endpoint that binds the whole row and checks a role inside.
- A receptionist may edit patient demographics but must not see allergies, so the patient representation they receive cannot carry clinical fields at all.

## Schema work this depends on

The policy above assumes things the schema does not have yet. These block the endpoints the rules would guard:

1. `doctor_service` — which services each doctor offers. Today `service` stands alone and `appointment` references a doctor and a service independently, so every doctor implicitly offers everything.
2. `allergies` on `patient`. Clinical data currently exists only as free text on `treatment_record`.
3. `price` on `service`, for the treatment menu.
4. `appointment.doctor_id` should reference `user_account`, now that `staff` and `doctor_profile` are gone.
5. Somewhere to hold a reschedule request. A new `notification` type is enough if nothing needs to list them; a small table of its own is better if a doctor should see pending requests and accept or decline them.

## How the rules get written

Role-only operations use plain `hasRole`. Anything ownership-scoped goes through a bean instead, so the policy lives in one testable place rather than being spelled out as expression strings across controllers:

```java
@PreAuthorize("@access.canReadTreatmentNotes(#patientId)")
```

The primitive underneath is `CurrentUser`, which reads the caller's account id off the request and is reachable from an expression directly when the check is just "is this you":

```java
@PreAuthorize("@currentUser.is(#userId)")
```

Rules that need to walk a relationship — is this doctor the one on that appointment, is this patient the subject of those notes — belong on the `@access` bean rather than being written inline.
