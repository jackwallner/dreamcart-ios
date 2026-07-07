-- The daily drop moved to GitHub Actions (jackwallner/dreamcart
-- .github/workflows/daily-drop.yml), which pre-renders every product image
-- into the product-art bucket before inserting the row. The pg_cron job
-- inserted products with on-demand pollinations URLs — retire it.
select cron.unschedule('dreamcart-daily-drop');
