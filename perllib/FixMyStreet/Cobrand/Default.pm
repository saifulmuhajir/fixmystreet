package FixMyStreet::Cobrand::Default;
use base 'FixMyStreet::Cobrand::Base';

use strict;
use warnings;
use FixMyStreet;
use URI;
use Digest::MD5 qw(md5_hex);

use Carp;
use mySociety::MaPit;
use mySociety::PostcodeUtil;

=head1 country

Returns the country that this cobrand operates in, as an ISO3166-alpha2 code.
Default is none.

=cut

sub country {
    return '';
}

=head1 problems_clause

Returns a hash for a query to be used by problems (and elsewhere in joined
queries) to restrict results for a cobrand.

=cut

sub problems_clause {}

=head1 problems

Returns a ResultSet of Problems, restricted to a subset if we're on a cobrand
that only wants some of the data.

=cut

sub problems {
    my $self = shift;
    return $self->{c}->model('DB::Problem');
}

=head1 site_restriction

Return a site key and a hash of extra query parameters if the cobrand uses a
subset of the FixMyStreet data. Parameter is any extra data the cobrand needs.
Returns a site key of 0 and an empty hash if the cobrand uses all the data.

=cut

sub site_restriction { return {}; }
sub site_key { return 0; }

=head2 restriction

Return a restriction to pull out data saved while using the cobrand site.

=cut

sub restriction {
    my $self = shift;

    return $self->moniker ? { cobrand => $self->moniker } : {};
}

=head2 base_url_with_lang 

=cut

sub base_url_with_lang {
    my $self = shift;
    return $self->base_url;
}

=head2 admin_base_url

Base URL for the admin interface.

=cut

sub admin_base_url { '' }

=head2 writetothem_url

URL for writetothem; parameter is COBRAND_DATA.

=cut

sub writetothem_url { 0 }

=head2 base_url

Return the base url for the cobranded version of the site

=cut

sub base_url { mySociety::Config::get('BASE_URL') }

=head2 base_url_for_report

Return the base url for a report (might be different in a two-tier county, but
most of the time will be same as base_url).

=cut

sub base_url_for_report {
    my ( $self, $report ) = @_;
    return $self->base_url;
}

=head2 base_host

Return the base host for the cobranded version of the site

=cut

sub base_host {
    my $self = shift;
    my $uri  = URI->new( $self->base_url );
    return $uri->host;
}

=head2 enter_postcode_text

Return the text that prompts the user to enter their postcode/place name.
Parameter is QUERY

=cut

sub enter_postcode_text { _('Enter a nearby street name and area') }

=head2 set_lang_and_domain

    my $set_lang = $cobrand->set_lang_and_domain( $lang, $unicode, $dir )

Set the language and domain of the site based on the cobrand and host.

=cut

sub set_lang_and_domain {
    my ( $self, $lang, $unicode, $dir ) = @_;
    my $set_lang = mySociety::Locale::negotiate_language(
        'en-gb,English,en_GB', $lang
    );
    mySociety::Locale::gettext_domain( 'FixMyStreet', $unicode, $dir );
    mySociety::Locale::change();
    return $set_lang;
}

=head2 alert_list_options

Return HTML for a list of alert options for the cobrand, given QUERY and
OPTIONS.

=cut

sub alert_list_options { 0 }

=head2 recent_photos

Return N recent photos. If EASTING, NORTHING and DISTANCE are supplied, the
photos must be attached to problems within DISTANCE of the point defined by
EASTING and NORTHING.

=cut

sub recent_photos {
    my $self = shift;
    my $area = shift;
    return $self->problems->recent_photos(@_);
}

=head2 recent

Return recent problems on the site.

=cut

sub recent {
    my ( $self ) = @_;
    return $self->problems->recent();
}

=item shorten_recency_if_new_greater_than_fixed

By default we want to shorten the recency so that the numbers are more
attractive.

=cut

sub shorten_recency_if_new_greater_than_fixed {
    return 1;
}

=head2 front_stats_data

Return a data structure containing the front stats information that a template
can then format.

=cut

sub front_stats_data {
    my ( $self ) = @_;

    my $recency         = '1 week';
    my $shorter_recency = '3 days';

    my $fixed   = $self->problems->recent_fixed();
    my $updates = $self->problems->number_comments();
    my $new     = $self->problems->recent_new( $recency );

    if ( $new > $fixed && $self->shorten_recency_if_new_greater_than_fixed ) {
        $recency = $shorter_recency;
        $new     = $self->problems->recent_new( $recency );
    }

    my $stats = {
        fixed   => $fixed,
        updates => $updates,
        new     => $new,
        recency => $recency,
    };

    return $stats;
}

=head2 disambiguate_location

Returns any disambiguating information available. Defaults to none.

=cut 

sub disambiguate_location { return {}; }

=head2 cobrand_data_for_generic_update

Parameter is UPDATE_DATA, a reference to a hash of non-cobranded update data.
Return cobrand extra data for the update

=cut

sub cobrand_data_for_generic_update { '' }

=head2 cobrand_data_for_generic_update

Parameter is PROBLEM_DATA, a reference to a hash of non-cobranded problem data.
Return cobrand extra data for the problem

=cut

sub cobrand_data_for_generic_problem { '' }

=head2 extra_problem_data

Parameter is QUERY. Return a string of extra data to be stored with a problem

=cut

sub extra_problem_data { '' }

=head2 extra_update_data

Parameter is QUERY. Return a string of extra data to be stored with an update

=cut 

sub extra_update_data { '' }

=head2 extra_alert_data

Parameter is QUERY. Return a string of extra data to be stored with an alert

=cut 

sub extra_alert_data { '' }

=head2 extra_data

Given a QUERY, extract any extra data required by the cobrand

=cut

sub extra_data { '' }

=head2 extra_problem_meta_text

Returns any extra text to be displayed with a PROBLEM.

=cut

sub extra_problem_meta_text { '' }

=head2 extra_update_meta_text

Returns any extra text to be displayed with an UPDATE.

=cut 

sub extra_update_meta_text { '' }

=head2 uri

Given a URL ($_[1]), QUERY, EXTRA_DATA, return a URL with any extra params
needed appended to it.

In the default case, if we're using an OpenLayers map, we need to make
sure zoom is always present if lat/lon are, to stop OpenLayers defaulting
to null/0.

=cut

sub uri {
    my ( $self, $uri ) = @_;

    (my $map_class = $FixMyStreet::Map::map_class) =~ s/^FixMyStreet::Map:://;
    return $uri unless $map_class =~ /OSM|FMS/;

    $uri->query_param( zoom => 3 )
      if $uri->query_param('lat') && !$uri->query_param('zoom');

    return $uri;
}


=head2 header_params

Return any params to be added to responses

=cut

sub header_params { return {} }

=head2 site_title

Return the title to be used in page heads.

=cut

sub site_title { 'FixMyStreet' }

=head2 site_name

Return short name for use in emails.

=cut
sub site_name {
    my $self = shift;
    $self->site_title;
}

=head2 map_type

Return an override type of map if necessary.

=cut
sub map_type {
    my $self = shift;
    return 'OSM' if $self->{c}->req->uri->host =~ /^osm\./;
    return;
}

=head2 reports_per_page

The number of reports to show per page on all reports page.

=cut

sub reports_per_page {
    return 100;
}

=head2 on_map_list_limit

Return the maximum number of items to be given in the list of reports on the map

=cut

sub on_map_list_limit { return undef; }

=head2 on_map_default_max_pin_age

Return the default maximum age for pins.

=cut

sub on_map_default_max_pin_age { return '6 months'; }

=head2 allow_photo_upload

Return a boolean indicating whether the cobrand allows photo uploads

=cut

sub allow_photo_upload { return 1; }

=head2 allow_crosssell_adverts

Return a boolean indicating whether the cobrand allows the display of crosssell
adverts

=cut

sub allow_crosssell_adverts { return 0; }

=head2 allow_photo_display

Return a boolean indicating whether the cobrand allows photo display

=cut

sub allow_photo_display { return 1; }

=head2 allow_update_reporting

Return a boolean indication whether users should see links next to updates
allowing them to report them as offensive.

=cut

sub allow_update_reporting { return 0; }

=head2 geocode_postcode

Given a QUERY, return LAT/LON and/or ERROR.

=cut

sub geocode_postcode {
    my ( $self, $s ) = @_;
    return {};
}

=head2 geocoded_string_check

Parameters are LOCATION, QUERY. Return a boolean indicating whether the
string LOCATION passes the cobrands checks.

=cut

sub geocoded_string_check { return 1; }

=head2 find_closest

Used by send-reports to attach nearest things to the bottom of the report

=cut

sub find_closest {
    my ( $self, $latitude, $longitude, $problem ) = @_;
    my $str = '';

    if ( my $j = FixMyStreet::Geocode::Bing::reverse( $latitude, $longitude, disambiguate_location()->{bing_culture} ) ) {
        # cache the bing results for use in alerts
        if ( $problem ) {
            $problem->geocode( $j );
            $problem->update;
        }
        if ($j->{resourceSets}[0]{resources}[0]{name}) {
            $str .= sprintf(_("Nearest road to the pin placed on the map (automatically generated by Bing Maps): %s"),
                $j->{resourceSets}[0]{resources}[0]{name}) . "\n\n";
        }
    }

    return $str;
}

=head2 find_closest_address_for_rss

Used by rss feeds to provide a bit more context

=cut

sub find_closest_address_for_rss {
    my ( $self, $latitude, $longitude, $problem ) = @_;
    my $str = '';

    my $j;
    if ( $problem && ref($problem) =~ /FixMyStreet/ && $problem->can( 'geocode' ) ) {
       $j = $problem->geocode;
    } else {
        $problem = FixMyStreet::App->model('DB::Problem')->find( { id => $problem->{id} } );
        $j = $problem->geocode;
    }

    # if we've not cached it then we don't want to look it up in order to avoid
    # hammering the bing api
    # if ( !$j ) {
    #     $j = FixMyStreet::Geocode::Bing::reverse( $latitude, $longitude, disambiguate_location()->{bing_culture}, 1 );

    #     $problem->geocode( $j );
    #     $problem->update;
    # }

    if ($j && $j->{resourceSets}[0]{resources}[0]{name}) {
        my $address = $j->{resourceSets}[0]{resources}[0]{address};
        my @address;
        push @address, $address->{addressLine} if $address->{addressLine} and $address->{addressLine} !~ /^Street$/i;
        push @address, $address->{locality} if $address->{locality};
        $str .= sprintf(_("Nearest road to the pin placed on the map (automatically generated by Bing Maps): %s"),
            join( ', ', @address ) ) if @address;
    }

    return $str;
}

=head2 format_postcode

Takes a postcode string and if it looks like a valid postcode then transforms it
into the canonical postcode.

=cut

sub format_postcode {
    my ( $self, $postcode ) = @_;

    if ( $postcode ) {
        $postcode = mySociety::PostcodeUtil::canonicalise_postcode($postcode)
            if $postcode && mySociety::PostcodeUtil::is_valid_postcode($postcode);
    }

    return $postcode;
}
=head2 council_check

Paramters are COUNCILS, QUERY, CONTEXT. Return a boolean indicating whether
COUNCILS pass any extra checks. CONTEXT is where we are on the site.

=cut

sub council_check { return ( 1, '' ); }

=head2 feed_xsl

Return an XSL to be used in rendering feeds

=cut

sub feed_xsl { '/xsl.xsl' }

=head2 all_councils_report

Return a boolean indicating whether the cobrand displays a report of all
councils

=cut

sub all_councils_report { 1 }

=head2 ask_ever_reported

Return a boolean indicating whether people should be asked whether this is the
first time they' ve reported a problem

=cut

sub ask_ever_reported { 1 }

=head2 send_questionnaires

Return a boolean indicating whether people should be sent questionnaire emails.

=cut

sub send_questionnaires { 1 }

=head2 admin_pages

List of names of pages to display on the admin interface

=cut

sub admin_pages { 0 }

=head2 admin_show_creation_graph

Show the problem creation graph in the admin interface
=cut

sub admin_show_creation_graph { 1 }

=head2 area_types, area_min_generation

The MaPit types this site handles

=cut

sub area_types          { qw(ZZZ) }
sub area_types_children { qw() }
sub area_min_generation { '' }

=head2 contact_name, contact_email

Return the contact name or email for the cobranded version of the site (to be
used in emails).

=cut

sub contact_name  { $_[0]->get_cobrand_conf('CONTACT_NAME') }
sub contact_email { $_[0]->get_cobrand_conf('CONTACT_EMAIL') }

=head2 get_cobrand_conf COBRAND KEY

Get the value for KEY from the config file for COBRAND

=cut

sub get_cobrand_conf {
    my ( $self, $key ) = @_;
    my $value           = undef;
    my $cobrand_moniker = $self->moniker;

    my $cobrand_config_file =
      FixMyStreet->path_to("conf/cobrands/$cobrand_moniker/general");
    my $normal_config_file = FixMyStreet->path_to('conf/general');

    if ( -e $cobrand_config_file ) {

        # FIXME - don't rely on the config file name - should
        # change mySociety::Config so that it can return values from a
        # particular config file instead
        mySociety::Config::set_file("$cobrand_config_file");
        my $config_key = $key . "_" . uc($cobrand_moniker);
        $value = mySociety::Config::get( $config_key, undef );
        mySociety::Config::set_file("$normal_config_file");
    }

    # If we didn't find a value use one from normal config
    if ( !defined($value) ) {
        $value = mySociety::Config::get($key);
    }

    return $value;
}

=item email_host

Return if we are the virtual host that sends email for this cobrand

=cut

sub email_host {
    return 1;
}

=item remove_redundant_councils

Remove councils whose reports go to another council

=cut

sub remove_redundant_councils {
  my $self = shift;
  my $all_councils = shift;
}

=item filter_all_council_ids_list

Removes any council IDs that we don't need from an array and returns the
filtered array

=cut

sub filter_all_council_ids_list {
  my $self = shift;
  return @_;
}

=item short_name

Remove extra information from council names for tidy URIs

=cut

sub short_name {
    my $self = shift;
    my ($area, $info) = @_;
    my $name = $area->{name};
    $name = URI::Escape::uri_escape_utf8($name);
    $name =~ s/%20/+/g;
    return $name;
}

=item is_council

For UK sub-cobrands, to specify various alternations needed for them.

=cut
sub is_council { 0; }

=item council_rss_alert_options

Generate a set of options for council rss alerts. 

=cut

sub council_rss_alert_options {
    my ( $self, $all_councils, $c ) = @_;

    my ( @options, @reported_to_options );
    foreach (values %$all_councils) {
        $_->{short_name} = $self->short_name( $_ );
        ( $_->{id_name} = $_->{short_name} ) =~ tr/+/_/;
        push @options, {
            type      => 'council',
            id        => sprintf( 'council:%s:%s', $_->{id}, $_->{id_name} ),
            text      => sprintf( _('Problems within %s'), $_->{name}),
            rss_text  => sprintf( _('RSS feed of problems within %s'), $_->{name}),
            uri       => $c->uri_for( '/rss/reports/' . $_->{short_name} ),
        };
    }

    return ( \@options, @reported_to_options ? \@reported_to_options : undef );
}

=head2 reports_council_check

This function is called by the All Reports page, and lets you do some cobrand
specific checking on the URL passed to try and match to a relevant area.

=cut

sub reports_council_check {
    my ( $self, $c, $code ) = @_;
    return 0;
}

=head2 default_photo_resize

Size that photos are to be resized to for display. If photos aren't
to be resized then return 0;

=cut

sub default_photo_resize { return 0; }

=head2 get_report_stats

Get stats to display on the council reports page

=cut

sub get_report_stats { return 0; }

sub get_council_sender { return 'Email' };

sub example_places {
    return [ 'High Street', 'Main Street' ];
}

sub process_extras {}

=head 2 pin_colour

Returns the colour of pin to be used for a particular report
(so perhaps different depending upon the age of the report).

=cut
sub pin_colour {
    my ( $self, $p, $context ) = @_;
    #return 'green' if time() - $p->confirmed_local->epoch < 7 * 24 * 60 * 60;
    return 'yellow' if $context eq 'around';
    return $p->is_fixed ? 'green' : 'red';
}

1;

