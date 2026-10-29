# Native scrolling headers

Shared header now supplies a native navigation title and action toolbar, retaining the date/mode controls. Today, Inbox, Upcoming list/agenda/month/three-day/day and project workspaces expose the navigation bar and native bounce. Selection hides the navigation bar and retains its selection header.

For iOS 18+, title mode responds to scroll position. Calendar day, three days and agenda use explicit main-scroll observers so untimed/overdue subregions do not drive it. Earlier iOS uses the native large-title fallback. Model, drag and resize recognizers are unchanged.

Validation: Simulator build passed before the final observer branching cleanup; final build recorded below. Synthetic Today calendar displayed a single native title and working controls. Full physical gesture/scroll matrix, title transition feel and older runtime checks remain unverified. No iPhone installation or TestFlight upload performed.

Final Simulator build: BUILD SUCCEEDED.
