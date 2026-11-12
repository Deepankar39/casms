# CASMS — Browser user guide

## Start and sign in
From the project root, start the server with `npm.cmd run dev`, then browse to `http://localhost:3000`. Log in with your assigned email and password. If prompted, change the temporary password before accessing the other modules. Do not reuse demo credentials in production.

## Dashboard
The Dashboard shows counts of visible assets and service requests, pending and overdue tickets, recent activities, and role-specific chart data. Admin may additionally see financial totals and warranty indicators. These metrics are read from MySQL and vary as data changes.

## Admin journey
1. Use **Master Data** to maintain active departments, buildings, rooms, categories and vendors.
2. Use **Users** to create Staff or Technician accounts; give their temporary passwords privately. Do not screenshot generated passwords.
3. Use **Assets** → register to create an asset and generated unique tag. Open the asset detail to edit allowed properties.
4. Use assignment and transfer actions to record custody/location changes. Review asset history before retirement.
5. Review Service Requests; assign open tickets to active, available technicians. Inspect timelines and maintenance work.
6. View **Reports** to filter/export CSV; **Audit** for database change history; **Notifications** for inbox events.

## Staff journey
1. Browse assets in your department or explicitly assigned to you.
2. Use **Service Requests** → New Request; choose eligible non-retired asset and priority; describe the issue.
3. Track your own requests and read comments/updates. Cancel your eligible Open request if needed.
4. After closure, provide feedback where permitted. Review your notifications and scoped reports.

## Technician journey
1. View only the tickets assigned to you; open the request detail.
2. Start an Assigned request. Move from In Progress to On Hold if waiting for parts; resume to In Progress.
3. Record diagnosis, work performed, labor cost, used parts/quantities and outcome.
4. Close the request via the closure workflow. It uses a stored procedure with transactional integrity.
5. Review service history, notifications and permitted scoped reports.

## Search and export
Assets, requests and reports support filtering/pagination. Reports export CSV from permitted results; Admin can use all ten reports, while Staff and Technicians receive four scoped reports. Data is limited by role on the server, not just by hiding menu items.

## Common errors
- **401:** Please sign in again; the session may have expired.
- **403:** Operation is outside your role or password change is required.
- **409:** Duplicate record or conflicting active request.
- **Validation error:** Check required fields and allowed values.

## Privacy and care
Demo data is synthetic. Do not share passwords, session cookies, `.env`, real staff personal information, or raw database backup files. Use only test records during the final demonstration.
