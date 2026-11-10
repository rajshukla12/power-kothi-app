# Partner API (app v1.1.0)

Base: `https://erp.powerkothi.in/power/power-kothi/api/v1/`
Every reply uses the existing envelope: `{"ok": true, "data": ...}` or `{"ok": false, "error": "message"}`.
All partner routes need `Authorization: Bearer <token>` (same token as the rest of the app).

## Login while SMS is off
- `POST auth/send-otp {mobile}` → `{"ok":true,"data":{"otp_test_mode":true}}` (no SMS sent)
- `POST auth/verify-otp {mobile, otp:"1234"}` → accepts 1234 for any valid mobile, creates the user if new
- `GET app/config` → include `"otp_test_mode": true` so the login screen shows "Enter 1234 as OTP"
- Turn off by setting the test-mode flag to false once the SMS gateway is live.

## Lead stages (status keys)
`submitted` → `survey_scheduled` → `feasibility_approved` → `agreement_signed` → `live`, or `rejected`.
Dashboard pipeline buckets: submitted = submitted, inspected = survey_scheduled,
approved = feasibility_approved + agreement_signed, live = live.

## GET partner/dashboard
```json
{"total_earnings": 12500, "wallet_balance": 4500, "pending_earnings": 6000, "live_count": 5,
 "pipeline": {"submitted": 3, "inspected": 2, "approved": 1, "live": 5},
 "leaderboard": [{"rank":1,"name":"Ravi K.","city":"Kanpur","live_count":9,"earnings":22500,"me":false}],
 "my_rank": {"rank":14,"name":"Arpit","city":"Kanpur","live_count":5,"earnings":12500}}
```
Leaderboard: top 10 by live chargers this month. `my_rank` only needed when the user is outside the top 10.

## POST partner/leads (multipart)
Fields: `owner_name`, `owner_phone` (10 digits), `property_type`, `lat`, `lng`. Files: `photo1` … `photo4` (at least one).
Returns the new lead `{"id": 41, "status": "submitted"}`.

## GET partner/leads
`[{"id":41,"owner_name":"Sharma Fuels","property_type":"Petrol pump","city":"Kanpur","status":"survey_scheduled","created_at":"10 Nov 2026","photo":"https://.../thumb.jpg","earning":2500}]`
The app polls this every 30 seconds while the list is open.

## GET partner/leads/{id}
```json
{"id":41,"owner_name":"Sharma Fuels","owner_phone":"9876543210","property_type":"Petrol pump","address":"GT Road, Kanpur",
 "lat":26.45,"lng":80.33,"status":"survey_scheduled","reject_reason":null,"earning":2500,
 "photos":["https://.../1.jpg"],
 "timeline":[{"status":"submitted","date":"10 Nov 2026, 6:10 pm","note":null},
             {"status":"survey_scheduled","date":"12 Nov 2026, 11:00 am","note":"Survey on 14 Nov by Amit"}]}
```

## GET partner/wallet
```json
{"balance":4500,"total_earned":12500,"total_paid":8000,"pending_payout":0,"min_payout":500,
 "bank":{"account_name":"Arpit","account_no":"1234567890","ifsc":"SBIN0001234","upi":""},
 "payouts":[{"amount":8000,"status":"paid","date":"1 Nov 2026","utr":"UTR123","note":null}],
 "transactions":[{"type":"credit","amount":2500,"remark":"Lead #33 charger live","date":"28 Oct 2026"}]}
```
`bank` is `null` until added. Payout status: `requested`, `paid`, `rejected`.

## POST partner/payout-request `{amount}`
Check amount ≥ min_payout and ≤ balance, and that a bank account or UPI is saved.

## PUT partner/bank `{account_name, account_no, ifsc, upi}`

## masters (optional)
Add `"property_types": ["Petrol pump", "Hotel / Restaurant / Dhaba", ...]` to `GET masters` to control the dropdown.
Without it the app shows a built-in list.
