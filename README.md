This is a [Next.js](https://nextjs.org) project bootstrapped with [`create-next-app`](https://nextjs.org/docs/app/api-reference/cli/create-next-app).

## Local V1 demo dataset

SD1 uses Supabase's normal `supabase/seed.sql` reset hook for deterministic,
Auth-independent fixture rows. A separate local-only script then provisions real
password-authenticated users through Supabase Admin Auth and builds the remaining
dataset through the application's existing workflow RPCs and private Storage
flow.

1. Start the local Supabase stack and reset it:

   ```powershell
   npx supabase start
   npx supabase db reset --local
   ```

2. Supply a temporary demo-only password in the current shell and run the
   bootstrap:

   ```powershell
   $env:LOGIFLOW_DEMO_PASSWORD = "choose-a-local-demo-password"
   npm run demo:bootstrap
   ```

3. Start the application with `npm run dev` and sign in with any documented
   demo username below using that same password. Re-run verification at any time
   with `npm run demo:verify`.

The bootstrap refuses non-local Supabase URLs, non-development rate-limit
environments, and Auth domains that do not end in `.local`. It also refuses to
merge fixtures into an already populated database; reset first instead. The
password is never stored in the repository.

| Role / state | Username |
| --- | --- |
| Active Admin | `demo.admin` |
| Inactive Admin | `demo.admin.inactive` |
| Dispatcher | `demo.dispatcher` |
| Assigned Driver | `demo.driver.assigned` |
| Loading Driver | `demo.driver.loading` |
| In-transit Driver | `demo.driver.transit` |
| Available Driver | `demo.driver.available` |
| Off-duty Driver | `demo.driver.offduty` |
| Inactive Driver | `demo.driver.inactive` |
| Archived Driver | `demo.driver.archived` |

`supabase db reset` intentionally restores only the deterministic foundation.
Run `npm run demo:bootstrap` after every reset to recreate Auth identities and
the workflow-driven operational fixtures.

The pgTAP suite assumes empty operational tables. Run it against an unseeded
reset, then restore the demo when finished:

```powershell
npx supabase db reset --local --no-seed
npx supabase test db
npx supabase db reset --local
npm run demo:bootstrap
```

## Getting Started

First, run the development server:

```bash
npm run dev
# or
yarn dev
# or
pnpm dev
# or
bun dev
```

Open [http://localhost:3000](http://localhost:3000) with your browser to see the result.

You can start editing the page by modifying `app/page.tsx`. The page auto-updates as you edit the file.

This project uses [`next/font`](https://nextjs.org/docs/app/building-your-application/optimizing/fonts) to automatically optimize and load [Geist](https://vercel.com/font), a new font family for Vercel.

## Learn More

To learn more about Next.js, take a look at the following resources:

- [Next.js Documentation](https://nextjs.org/docs) - learn about Next.js features and API.
- [Learn Next.js](https://nextjs.org/learn) - an interactive Next.js tutorial.

You can check out [the Next.js GitHub repository](https://github.com/vercel/next.js) - your feedback and contributions are welcome!

## Deploy on Vercel

The easiest way to deploy your Next.js app is to use the [Vercel Platform](https://vercel.com/new?utm_medium=default-template&filter=next.js&utm_source=create-next-app&utm_campaign=create-next-app-readme) from the creators of Next.js.

Check out our [Next.js deployment documentation](https://nextjs.org/docs/app/building-your-application/deploying) for more details.
