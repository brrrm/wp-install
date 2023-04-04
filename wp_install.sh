#!/bin/bash -e

# Ideas, Drawbacks, and Suggestions: https://davidlaietta.com/bash-scripting-to-automate-site-builds-with-wp-cli/

# Set up some defaults
default_user="bram"
default_email="bramdeleeuw@gmail.com"

clear

echo "===================================="
echo " Webshoplocatie Wordpress installer "
echo "===================================="
echo ""

echo "Please enter the domain name (without www):"
# read -e domain
read -p "Domain: " domain

echo "Please enter the name for this webshop:"
# read -e domain
IFS= read -r -p "Webshop name: " shopname

echo "Please enter the database name:"
# read -e domain
read -p "Databse: " db

echo "Please enter the database user:"
# read -e domain
read -p "Databse user: " dbuser

echo "Please enter the database user password:"
# read -e domain
IFS= read -r -p "Databse user: " dbuserpw

echo "Please enter the username for user 1: [$default_user] "
IFS= read -r -p "Username: " wpuser
wpuser=${wpuser:-$default_user}

echo "Please enter the enail for user 1: [$default_email] "
read -p "Username: " email
email=${email:-$default_email}

# Generate a random 20 alphanumeric character password for the default user
password=$(env LC_CTYPE=C tr -dc "A-Za-z0-9" < /dev/urandom | head -c 20)

# Copy the password to the clipboard
echo "Below you'll find your password. It's copied to your memory. Please store it somewhere safe!"
echo $password


# ~/public_html leegmaken!!!
cd ~/public_html
rm -rf *

# download WP
wp core download --locale=nl_NL
# set up wp-config.php
wp config create --dbname="$db" --dbuser="$dbuser" --dbpass="$dbuserpw" --locale=nl_NL
# install WP
wp core install --url=https://"$domain" --title="$shopname" --admin_user="$wpuser" --admin_password="$password" --admin_email="$email" --skip-email


# Delete the default plugins and themes that we don't need
wp plugin delete hello
wp theme delete twentytwenty
wp theme delete twentytwentyone
wp theme install storefront
#install our subtheme
mkdir wp-content/themes/webshoplocatie
git clone https://github.com/brrrm/webshoplocatie-storefront-subtheme.git wp-content/themes/webshoplocatie/
wp theme activate webshoplocatie

wp plugin install woocommerce --activate
wp plugin install mollie-payments-for-woocommerce --activate
wp plugin install wordpress-seo --activate
wp plugin install ean-for-woocommerce --activate
wp plugin install woocommerce-pdf-invoices-packing-slips --activate
wp plugin install woo-media-api --activate


# delete sample post
wp post delete $(wp post list --post_type=post --posts_per_page=1 --post_status=publish --postname="hello-world" --field=ID --format=ids) --force
# delete sample page, and create homepage
wp post delete $(wp post list --post_type=page --posts_per_page=1 --post_status=publish --pagename="voorbeeld-pagina" --field=ID --format=ids) --force
# wp post create --post_type=page --post_title=Home --post_status=publish --post_author=$(wp user get "$wpuser" --field=ID)

# Add a comma separated list of pages
allpages="Over ons,Blog,Contact"
# create all of the pages
IFS=","
for page in $allpages
do
	wp post create --post_type=page --post_status=publish --post_author=$(wp user get "$wpuser" --field=ID) --post_title="$(echo "$page" | sed -e 's/^ *//' -e 's/ *$//')"
done

# set page as front page
wp option update show_on_front "page"
# set "Home" to be the new page
wp option update page_on_front $(wp post list --post_type=page --post_status=publish --posts_per_page=1 --pagename=shop --field=ID)
# set "Blog" to be the new blogpage
wp option update page_for_posts $(wp post list --post_type=page --post_status=publish --posts_per_page=1 --pagename=blog --field=ID)


# # Set permalinks to postname
wp rewrite structure "/%postname%/" --hard
wp rewrite flush --hard

# Create a navigation bar
wp menu create "Main\ Navigation"

# Add pages to navigation
IFS=" "
for pageid in $(wp post list --order="ASC" --orderby="date" --post_type=page --post_status=publish --posts_per_page=-1 --field=ID --format=ids);
do
	wp menu item add-post main-navigation $pageid
done

# Assign navigation to primary location
wp menu location assign main-navigation primary
# move webshop menu items
# wp menu item update $(wp post list --post_type=nav_menu_item --posts_per_page=1  --meta_key=_menu_item_object_id --meta_value=$(wp post list --post_type=page --posts_per_page=1 --pagename=shop --field=ID) --field=ID) --position=1
wp menu item delete $(wp post list --post_type=nav_menu_item --posts_per_page=1  --meta_key=_menu_item_object_id --meta_value=$(wp post list --post_type=page --posts_per_page=1 --pagename=cart --field=ID) --field=ID)
wp menu item delete $(wp post list --post_type=nav_menu_item --posts_per_page=1  --meta_key=_menu_item_object_id --meta_value=$(wp post list --post_type=page --posts_per_page=1 --pagename=checkout --field=ID) --field=ID)
wp menu item delete $(wp post list --post_type=nav_menu_item --posts_per_page=1  --meta_key=_menu_item_object_id --meta_value=$(wp post list --post_type=page --posts_per_page=1 --pagename=my-account --field=ID) --field=ID)


# Remove default widgets from sidebar
widgetids=$(wp widget list sidebar-1 --format=ids)
wp widget delete $widgetids


# Create a category called "News" and set it as default
wp term create category Nieuws
wp option update default_category $(wp term list category --name=nieuws --field=id)


# Setup webshop and other options
wp option update blogdescription "Webshoplocatie webkassa"
wp option update timezone_string "Europe/Amsterdam"
wp option update woocommerce_store_address "Cruquiuszoom 51"
wp option update woocommerce_store_city "Cruquius"
wp option update woocommerce_default_country "NL"
wp option update woocommerce_store_postcode "2142 EW"
wp option update woocommerce_calc_taxes "yes"
wp option update woocommerce_enable_coupons "no"
wp option update woocommerce_currency "EUR"
wp option update woocommerce_price_thousand_sep "."
wp option update woocommerce_price_decimal_sep ","
wp option update woocommerce_prices_include_tax "yes"
wp option update woocommerce_tax_based_on "billing"
wp option update woocommerce_tax_display_shop "incl"
wp option update woocommerce_tax_display_cart "incl"
wp option update alg_wc_ean_product_rest "yes"
wp option update alg_wc_ean_product_search_rest "yes"

# tax the sit out of it!!!
wp wc tax create --rate="21" --priority="1" --name="BTW-hoog" --class="standard" --user=1
wp wc tax create --rate="9" --priority="1" --name="BTW-laag" --class="reduced-rate" --user=1
wp wc tax create --rate="0" --priority="1" --name="BTW-vrij" --class="zero-rate" --user=1

wp option update woocommerce_shipping_tax_class ""
wp option update attach_to_email_ids_customer_completed_order "yes"
wp option update attach_to_email_ids_customer_refunded_order "yes"
wp option update attach_to_email_ids_customer_invoice "yes"
wp option update wpo_wcpdf_documents_settings_packing-slip '{"enabled":0,"display_billing_address":0,"display_customer_notes":"0"}' --format=json
wp option update wpo_wcpdf_documents_settings_invoice '{"enabled":1,"attach_to_email_ids":{"customer_completed_order":1,"customer_refunded_order":1},"display_shipping_address":"when_different","display_email":1,"display_phone":1,"display_customer_notes":0,"display_date":"invoice_date","display_number":"invoice_number","number_format":{"prefix":"","suffix":"","padding":""},"my_account_buttons":"available"}' --format=json
wp option update wpo_wcpdf_settings_general '{"download_display":"display","template_path":"default/Simple","currency_font":"","paper_size":"a4"}' --format=json
wp option update wpseo '{"tracking":false,"license_server_version":false,"ms_defaults_set":false,"ignore_search_engines_discouraged_notice":false,"indexing_first_time":false,"indexing_started":false,"indexing_reason":"","indexables_indexing_completed":false,"index_now_key":"","version":"19.7.1","previous_version":"","disableadvanced_meta":true,"enable_headless_rest_endpoints":true,"ryte_indexability":false,"baiduverify":"","googleverify":"","msverify":"","yandexverify":"","site_type":"","has_multiple_authors":"","environment_type":"","content_analysis_active":false,"keyword_analysis_active":false,"inclusive_language_analysis_active":false,"enable_admin_bar_menu":true,"enable_cornerstone_content":true,"enable_xml_sitemap":false,"enable_text_link_counter":true,"enable_index_now":true,"show_onboarding_notice":true,"first_activated_on":false,"myyoast-oauth":false,"semrush_integration_active":false,"semrush_tokens":[],"semrush_country_code":"us","permalink_structure":"","home_url":"","dynamic_permalinks":false,"category_base_url":"","tag_base_url":"","custom_taxonomy_slugs":[],"enable_enhanced_slack_sharing":true,"zapier_integration_active":false,"zapier_subscription":[],"zapier_api_key":"","enable_metabox_insights":true,"enable_link_suggestions":true,"algolia_integration_active":false,"import_cursors":[],"workouts_data":{"configuration":{"finishedSteps":[]}},"configuration_finished_steps":[],"dismiss_configuration_workout_notice":false,"dismiss_premium_deactivated_notice":false,"importing_completed":[],"wincher_integration_active":false,"wincher_tokens":[],"wincher_automatically_add_keyphrases":false,"wincher_website_id":"","wordproof_integration_active":false,"wordproof_integration_changed":false,"first_time_install":false,"should_redirect_after_install_free":false,"activation_redirect_timestamp_free":false,"remove_feed_global":false,"remove_feed_global_comments":false,"remove_feed_post_comments":false,"remove_feed_authors":false,"remove_feed_categories":false,"remove_feed_tags":false,"remove_feed_custom_taxonomies":false,"remove_feed_post_types":false,"remove_feed_search":false,"remove_atom_rdf_feeds":false,"remove_shortlinks":false,"remove_rest_api_links":false,"remove_rsd_wlw_links":false,"remove_oembed_links":false,"remove_generator":false,"remove_emoji_scripts":false,"remove_powered_by_header":false,"remove_pingback_header":false,"clean_campaign_tracking_urls":false,"clean_permalinks":false,"clean_permalinks_extra_variables":"","search_cleanup":false,"search_cleanup_emoji":false,"search_cleanup_patterns":false,"search_character_limit":50,"deny_search_crawling":false,"deny_wp_json_crawling":false,"least_readability_ignore_list":[],"least_seo_score_ignore_list":[],"most_linked_ignore_list":[],"least_linked_ignore_list":[],"indexables_page_reading_list":[false,false,false,false,false],"indexables_overview_state":"dashboard-not-visited"}' --format=json
wp option update wpseo_titles '{"forcerewritetitle":false,"separator":"sc-dash","title-home-wpseo":"%%sitename%% %%page%% %%sep%% %%sitedesc%%","title-author-wpseo":"%%name%%, Author at %%sitename%% %%page%%","title-archive-wpseo":"%%date%% %%page%% %%sep%% %%sitename%%","title-search-wpseo":"You searched for %%searchphrase%% %%page%% %%sep%% %%sitename%%","title-404-wpseo":"Page not found %%sep%% %%sitename%%","social-title-author-wpseo":"%%name%%","social-title-archive-wpseo":"%%date%%","social-description-author-wpseo":"","social-description-archive-wpseo":"","social-image-url-author-wpseo":"","social-image-url-archive-wpseo":"","social-image-id-author-wpseo":0,"social-image-id-archive-wpseo":0,"metadesc-home-wpseo":"","metadesc-author-wpseo":"","metadesc-archive-wpseo":"","rssbefore":"","rssafter":"The post %%POSTLINK%% appeared first on %%BLOGLINK%%.","noindex-author-wpseo":true,"noindex-author-noposts-wpseo":true,"noindex-archive-wpseo":true,"disable-author":false,"disable-date":false,"disable-post_format":false,"disable-attachment":true,"breadcrumbs-404crumb":"Error 404: Page not found","breadcrumbs-display-blog-page":true,"breadcrumbs-boldlast":false,"breadcrumbs-archiveprefix":"Archives for","breadcrumbs-enable":true,"breadcrumbs-home":"Home","breadcrumbs-prefix":"","breadcrumbs-searchprefix":"You searched for","breadcrumbs-sep":"\u00bb","website_name":"","person_name":"","person_logo":"","person_logo_id":0,"alternate_website_name":"","company_logo":"","company_logo_id":0,"company_logo_meta":false,"person_logo_meta":false,"company_name":"","company_or_person":"company","company_or_person_user_id":false,"stripcategorybase":false,"open_graph_frontpage_title":"%%sitename%%","open_graph_frontpage_desc":"","open_graph_frontpage_image":"","open_graph_frontpage_image_id":0,"title-post":"%%title%% %%page%% %%sep%% %%sitename%%","metadesc-post":"","noindex-post":true,"display-metabox-pt-post":true,"post_types-post-maintax":0,"schema-page-type-post":"WebPage","schema-article-type-post":"Article","social-title-post":"%%title%%","social-description-post":"","social-image-url-post":"","social-image-id-post":0,"title-page":"%%title%% %%page%% %%sep%% %%sitename%%","metadesc-page":"","noindex-page":true,"display-metabox-pt-page":true,"post_types-page-maintax":"0","schema-page-type-page":"WebPage","schema-article-type-page":"None","social-title-page":"%%title%%","social-description-page":"","social-image-url-page":"","social-image-id-page":0,"title-attachment":"%%title%% %%page%% %%sep%% %%sitename%%","metadesc-attachment":"","noindex-attachment":false,"display-metabox-pt-attachment":true,"post_types-attachment-maintax":"0","schema-page-type-attachment":"WebPage","schema-article-type-attachment":"None","title-tax-category":"%%term_title%% Archives %%page%% %%sep%% %%sitename%%","metadesc-tax-category":"","display-metabox-tax-category":true,"noindex-tax-category":true,"social-title-tax-category":"%%term_title%% Archives","social-description-tax-category":"","social-image-url-tax-category":"","social-image-id-tax-category":0,"title-tax-post_tag":"%%term_title%% Archives %%page%% %%sep%% %%sitename%%","metadesc-tax-post_tag":"","display-metabox-tax-post_tag":true,"noindex-tax-post_tag":true,"social-title-tax-post_tag":"%%term_title%% Archives","social-description-tax-post_tag":"","social-image-url-tax-post_tag":"","social-image-id-tax-post_tag":0,"title-tax-post_format":"%%term_title%% Archives %%page%% %%sep%% %%sitename%%","metadesc-tax-post_format":"","display-metabox-tax-post_format":false,"noindex-tax-post_format":true,"social-title-tax-post_format":"%%term_title%% Archives","social-description-tax-post_format":"","social-image-url-tax-post_format":"","social-image-id-tax-post_format":0,"title-product":"%%title%% %%page%% %%sep%% %%sitename%%","metadesc-product":"","noindex-product":true,"display-metabox-pt-product":true,"post_types-product-maintax":0,"schema-page-type-product":"WebPage","schema-article-type-product":"None","social-title-product":"%%title%%","social-description-product":"","social-image-url-product":"","social-image-id-product":0,"title-ptarchive-product":"%%pt_plural%% Archive %%page%% %%sep%% %%sitename%%","metadesc-ptarchive-product":"","bctitle-ptarchive-product":"","noindex-ptarchive-product":false,"social-title-ptarchive-product":"%%pt_plural%% Archive","social-description-ptarchive-product":"","social-image-url-ptarchive-product":"","social-image-id-ptarchive-product":0,"title-tax-product_cat":"%%term_title%% Archives %%page%% %%sep%% %%sitename%%","metadesc-tax-product_cat":"","display-metabox-tax-product_cat":true,"noindex-tax-product_cat":true,"social-title-tax-product_cat":"%%term_title%% Archives","social-description-tax-product_cat":"","social-image-url-tax-product_cat":"","social-image-id-tax-product_cat":0,"taxonomy-product_cat-ptparent":0,"title-tax-product_tag":"%%term_title%% Archives %%page%% %%sep%% %%sitename%%","metadesc-tax-product_tag":"","display-metabox-tax-product_tag":true,"noindex-tax-product_tag":true,"social-title-tax-product_tag":"%%term_title%% Archives","social-description-tax-product_tag":"","social-image-url-tax-product_tag":"","social-image-id-tax-product_tag":0,"taxonomy-product_tag-ptparent":0,"title-tax-product_shipping_class":"%%term_title%% Archives %%page%% %%sep%% %%sitename%%","metadesc-tax-product_shipping_class":"","display-metabox-tax-product_shipping_class":true,"noindex-tax-product_shipping_class":true,"social-title-tax-product_shipping_class":"%%term_title%% Archives","social-description-tax-product_shipping_class":"","social-image-url-tax-product_shipping_class":"","social-image-id-tax-product_shipping_class":0,"taxonomy-product_shipping_class-ptparent":0,"taxonomy-category-ptparent":"0","taxonomy-post_tag-ptparent":"0","taxonomy-post_format-ptparent":"0"}' --format=json
wp option update wpseo_social '{"facebook_site":"","instagram_url":"","linkedin_url":"","myspace_url":"","og_default_image":"","og_default_image_id":"","og_frontpage_title":"","og_frontpage_desc":"","og_frontpage_image":"","og_frontpage_image_id":"","opengraph":true,"pinterest_url":"","pinterestverify":"","twitter":true,"twitter_site":"","twitter_card_type":"summary_large_image","youtube_url":"","wikipedia_url":"","other_social_urls":[]}' --format=json
wp option update theme_mods_webshoplocatie '{"nav_menu_locations":{"primary":16},"custom_css_post_id":-1,"custom_logo":"","header_image":"remove-header","storefront_header_link_color":"#678aa7","storefront_footer_link_color":"#678aa7","storefront_accent_color":"#678aa7","storefront_button_background_color":"#678aa7","storefront_button_text_color":"#ffffff","storefront_button_alt_background_color":"#333333"}' --format=json

# clear the bash history so the password can't be retrieved from the history
history -c

echo ""
echo ""
echo "======================================="
echo " WHAM BAM! THANK YOU M'AM!"
echo ""
echo " Below you'll find your password. It's "
echo " copied to your memory. Please store it "
echo " somewhere safe!"
echo "======================================="
echo $password
echo "======================================="

# Open the new website with Google Chrome
# open -a /Applications/Google\ Chrome.app https://$domain/
