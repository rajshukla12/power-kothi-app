# Partner API (app v1.1.0, backend power-kothi)

Base: `https://erp.powerkothi.in/power/power-kothi/api/v1/`. Reply: `{"ok": true, "data": ...}` or `{"ok": false, "error": "..."}`.
All partner routes need `Authorization: Bearer <token>`. Code: `application/controllers/api/Gateway.php` (partner section at the end).

A **partner is an employee** (Admin > Employees) whose mobile matches the logged-in app user.
Commission per stage comes from Admin > Commission Rules and is credited by `Lead_model::change_stage()`.

## OTP while SMS is off
Admin > Settings > SMS OTP > "Test OTP 1234" (`otp_test_mode`, default 1). While on, no SMS is sent and 1234 logs in any number.
`app/config` and `auth/send-otp` return `otp_test_mode: true`, so the login screen shows the hint. Set it to 0 once SMS is live.

## Lead stages
| key | admin + app label | dashboard bucket |
|---|---|---|
| new | Submitted | Submitted |
| verified | Site Survey Scheduled | Submitted |
| site_visit | Feasibility Approved | Inspected |
| agreement | Agreement Signed | Approved |
| installed | Charger Live | Live |
| rejected | Rejected | - |

## Routes
- `GET partner/status` → `{is_partner, can_join, kyc_done, docs:{aadhaar, photo}, partner:{name, mobile, email, emp_code, referral_code}, per_lead}`
- `POST partner/join` (multipart) `name, email (optional), aadhaar_front, aadhaar_back (optional), photo` → creates the employee if needed (only if Settings > Wallets > "App users can join as partner" = 1) and stores Aadhaar + photo as private employee documents. The app shows the dashboard only when `kyc_done` is true; an admin rejecting either document sends the partner back to this form.
- `GET partner/dashboard` → `{total_earnings, wallet_balance, pending_earnings, live_count, per_lead, pipeline:{submitted, inspected, approved, live}, leaderboard:[{rank,name,city,earnings,live_count,me}], my_rank}`
- `GET partner/leads` → `[{id, lead_no, owner_name, property_type, status, status_label, city, reject_reason, created_at, earned, earning}]`
- `GET partner/leads/{id}` → lead + `owner_phone, address, lat, lng, photo_count, timeline:[{status, date, note}]`
- `POST partner/leads` (multipart) `owner_name, owner_phone, property_type (key from masters.property_types), lat, lng, photo1..photo4` → `{id, status, photos_saved}`. Photos are stored as private "Site photo" documents on the lead (Admin > Station Leads > lead > Documents).
- `GET partner/wallet` → `{balance, pending_payout, total_earned, total_paid, min_payout, bank, bank_locked, payouts:[...], transactions:[...]}`
- `POST partner/payout-request {amount}`
- `PUT partner/bank {account_name, account_no, ifsc, upi}` → allowed once; changes after that only by admin (Bank Payouts access)
- `GET masters` now includes `property_types: [{key, name}]`
