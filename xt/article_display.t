use strict;
use warnings;

use RT::Extension::ConditionalCustomFields::Test tests => 14;

use WWW::Mechanize::PhantomJS;

RT->Config->Set('JSFiles', qw/conditional-customfields.js/);
my $cf_condition = RT::CustomField->new(RT->SystemUser);
$cf_condition->Create(Name => 'Condition', LookupType => 'RT::Class-RT::Article', Type => 'Select', MaxValues => 1);
$cf_condition->AddValue(Name => 'Passed', SortOder => 0);
$cf_condition->AddValue(Name => 'Failed', SortOrder => 1);
$cf_condition->AddValue(Name => 'Schrödingerized', SortOrder => 2);
my $cf_values = $cf_condition->Values->ItemsArrayRef;

my $cf_conditioned_by = RT::CustomField->new(RT->SystemUser);
$cf_conditioned_by->Create(Name => 'ConditionedBy', LookupType => 'RT::Class-RT::Article', Type => 'Freeform', MaxValues => 1);

my $cf_conditioned_by_child = RT::CustomField->new(RT->SystemUser);
$cf_conditioned_by_child->Create(Name => 'Child', LookupType => 'RT::Class-RT::Article', Type => 'Freeform', MaxValues => 1, BasedOn => $cf_conditioned_by->id);

my $class = RT::Class->new(RT->SystemUser);
$class->Load('General');
my $article = RT::Article->new(RT->SystemUser);
$article->Create(Class => $class->Name, Name => 'Test Article ConditionalCF');
$cf_condition->AddToObject($class);
$cf_conditioned_by->AddToObject($class);
$cf_conditioned_by_child->AddToObject($class);
$article->AddCustomFieldValue(Field => $cf_condition->id , Value => $cf_values->[0]->Name);
$article->AddCustomFieldValue(Field => $cf_conditioned_by->id , Value => 'See me?');
$article->AddCustomFieldValue(Field => $cf_conditioned_by_child->id , Value => 'See me too?');

my ($base, $m) = RT::Extension::ConditionalCustomFields::Test->started_ok;
my $mjs = WWW::Mechanize::PhantomJS->new();
$mjs->driver->ua->timeout(540);
$mjs->get($m->rt_base_url . '?user=root;pass=password');

$mjs->get($m->rt_base_url . 'Articles/Article/Display.html?id=' . $article->id);
my $article_cf_conditioned_by = $mjs->selector('#CF-'. $cf_conditioned_by->id . '-ShowRow', single => 1);
ok($article_cf_conditioned_by->is_displayed, 'Show ConditionalCF when no condition is set');
my $article_cf_conditioned_by_child = $mjs->selector('#CF-'. $cf_conditioned_by_child->id . '-ShowRow', single => 1);
ok($article_cf_conditioned_by_child->is_displayed, 'Show Child when no condition is set');

$cf_conditioned_by->SetConditionedBy($cf_condition->id, 'is', [$cf_values->[0]->Name, $cf_values->[2]->Name]);
$mjs->get($m->rt_base_url . 'Articles/Article/Display.html?id=' . $article->id);
$article_cf_conditioned_by = $mjs->selector('#CF-'. $cf_conditioned_by->id . '-ShowRow', single => 1);
ok($article_cf_conditioned_by->is_displayed, 'Show ConditionalCF when condition is met by first val');
$article_cf_conditioned_by_child = $mjs->selector('#CF-'. $cf_conditioned_by_child->id . '-ShowRow', single => 1);
ok($article_cf_conditioned_by_child->is_displayed, 'Show Child when condition is met by first val');

$article->AddCustomFieldValue(Field => $cf_condition->id , Value => $cf_values->[1]->Name);
$mjs->get($m->rt_base_url . 'Articles/Article/Display.html?id=' . $article->id);
$article_cf_conditioned_by = $mjs->selector('#CF-'. $cf_conditioned_by->id . '-ShowRow', single => 1);

ok($article_cf_conditioned_by->is_hidden, 'Hide ConditionalCF when condition is not met');
$article_cf_conditioned_by_child = $mjs->selector('#CF-'. $cf_conditioned_by_child->id . '-ShowRow', single => 1);
ok($article_cf_conditioned_by_child->is_hidden, 'Hide Child when condition is not met');

$article->AddCustomFieldValue(Field => $cf_condition->id , Value => $cf_values->[2]->Name);
$mjs->get($m->rt_base_url . 'Articles/Article/Display.html?id=' . $article->id);
$article_cf_conditioned_by = $mjs->selector('#CF-'. $cf_conditioned_by->id . '-ShowRow', single => 1);
ok($article_cf_conditioned_by->is_displayed, 'Show ConditionalCF when condition is met by second val');
$article_cf_conditioned_by_child = $mjs->selector('#CF-'. $cf_conditioned_by_child->id . '-ShowRow', single => 1);
ok($article_cf_conditioned_by_child->is_displayed, 'Show Child when condition is met by second val');
