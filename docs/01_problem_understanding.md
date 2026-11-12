# Problem Understanding – Uber Ride-Hailing Database

## Business Context

Uber India operates in 10 cities. The database handles riders, drivers, vehicles, trips, payments, promo codes and ratings. The existing database has no documented schema, and the business teams have reported performance and data-related problems.

## Problem Statements

| ID | Business Need | Stakeholder | Classification |
|---|---|---|---|
| P1 | Load a rider's recent trip history quickly, even for frequent riders. | Rider | Customer-facing / Real-time |
| P2 | Display drivers' trip earnings quickly throughout the day. | Driver | Customer-facing / Real-time |
| P3 | Support case-insensitive email login without making authentication slow. | Rider / Driver | Customer-facing / Real-time |
| P4 | Refresh the live dispatch screen within 3 seconds under load. | City Operations | Customer-facing / Real-time |
| P5 | Generate monthly revenue, payment-method and failed-payment reports without timeouts. | Finance | Reporting / Analytics |
| P6 | Return accurate lists of inactive riders and drivers for win-back campaigns. | Marketing / Driver Operations | Reporting / Analytics |
| P7 | Identify unusually long trips and trips with unusually high fares efficiently. | Trust & Safety | Reporting / Analytics |
| P8 | Keep trip pagination in the admin panel responsive, even on later pages. | Admin | Customer-facing / Real-time |
| P9 | Make surge, cancellation, growth and rating dashboards faster and support 10–20× trip growth. | Leadership / Analytics | Reporting / Analytics |

## Assumptions

1. The eight supplied CSV files represent the available production data.
2. The database must support all 10 operating cities.
3. Existing query results must remain unchanged during optimization.
4. Real-time and interactive operations need faster response times than analytical reports.
5. The database should be designed to support the expected increase in trip volume.
6. Missing or optional values in the CSV files must be understood before defining constraints.