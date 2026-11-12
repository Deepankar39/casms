# Role and permission matrix (CASMS Phase 5 implementation)

| Operation | Admin | Staff | Technician |
|---|:---:|:---:|:---:|
| Login/logout, own profile/password | Yes | Yes | Yes |
| Dashboard and scoped inventory | All | Own department/assigned | Related assigned tickets |
| View requests | All | Raised by self | Assigned to self |
| Register/edit/retire assets | Yes | No | No |
| Manage departments, buildings, rooms, categories, vendors | Yes | View | View |
| Create/deactivate users | Yes | No | No |
| Assign/transfers assets | Yes | No | No |
| Raise service request | Yes | Yes (eligible assets) | No |
| Assign/reassign technician | Yes | No | No |
| Start, hold, resume repair | Yes | No | Assigned only |
| Record maintenance and close request | Yes | No | Assigned only |
| Cancel request | Eligible tickets | Own eligible Open tickets | No |
| Reopen closed request | Yes | No | No |
| Feedback on request | No | Own resolved ticket | No |
| Read notification / mark own read | Yes | Yes | Yes |
| Reports and CSV | All 10 | 4 scoped | 4 scoped |
| Audit viewer | Yes | No | No |

API permissions are enforced in Express routes and scope helpers; hiding a menu item alone is not an authorization boundary. Review the source routes for the definitive behavior if it changes.
