#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "const-c.inc"

MODULE = Local::Stats		PACKAGE = Local::Stats		

INCLUDE: const-xs.inc

SV *new(class, coderef)
    char *class
    SV *coderef
    PPCODE:
        ENTER; SAVETMPS;
        HV *hash = (HV *)sv_2mortal((SV *)newHV());
        hv_store(hash, "get_settings", strlen("get_settings"), newSVsv(coderef), 0);
        hv_store(hash, "stats", strlen("stats"), newRV(sv_2mortal((SV *)newHV())), 0);
        SV *href = newRV((SV *)hash);
        SV *self = sv_bless(href, gv_stashpv(class, TRUE));
        FREETMPS; LEAVE;
        XPUSHs(sv_2mortal(self));


void add(self, name, value)
    SV *self
    char *name
    double value
    PPCODE:
        ENTER; SAVETMPS;
        if (!(SvOK(self) && SvROK(self))) {
            croak("self must be a hashref");
        }
        if (!(sv_isobject(self) && sv_isa(self, "Local::Stats"))) {
            croak("self must be an Local::Stats object");
        }
        HV *hself = (HV *)(SvRV(self));
        if (!hv_exists(hself, "stats", strlen("stats"))) {
            croak("self->{stats} key expected");
        }
        SV **_stats = hv_fetch(hself, "stats", strlen("stats"), 0);
        if (!_stats) {
            croak("self->{stats} hashref expected. NULL found");
        }
        HV *stats = (HV *)(SvRV(*_stats));
        if (!hv_exists(stats, name, strlen(name))) {
            if (!hv_exists(hself, "get_settings", strlen("get_settings"))) {
                croak("self->{get_settings} member function expected");
            }
            SV **_get_settings_sub = hv_fetch(hself, "get_settings", strlen("get_settings"), 0);
            if (!(_get_settings_sub && SvTYPE(SvRV(*_get_settings_sub)) == SVt_PVCV)) {
                croak("self->{get_settings} expected to be a sub");
            }
            SV *get_settings_sub = SvRV(*_get_settings_sub);
            PUSHMARK(SP);
            XPUSHs(sv_2mortal(newSVpv(name, strlen(name))));
            PUTBACK;
            int count = call_sv(get_settings_sub, G_ARRAY);
            SPAGAIN;
            HV *params = (HV *)sv_2mortal((SV *)newHV());
            int i;
            for (i = 0; i < count; ++i) {
                SV *param = newSVsv(POPs);
                char *param_name = (char *)SvPV_nolen(param);
                hv_store(params, param_name, strlen(param_name), newSV(0), 0);
            }
            SV *rparams = newRV((SV *)params);
            hv_store(stats, name, strlen(name), rparams, 0);
            SV *rstats = newRV((SV *)stats);
            hv_store(hself, "stats", strlen("stats"), rstats, 0);
            self = newRV((SV *)hself);
        }
        SV **_metric_stats = hv_fetch(stats, name, strlen(name), 0);
        if (!(_metric_stats && SvTYPE(SvRV(*_metric_stats)) == SVt_PVHV)) {
            croak("self->{stats}->{%s} expected to be a hashref", name);
        }
        HV *metric_stats = (HV *)SvRV(*_metric_stats);
        if (hv_exists(metric_stats, "avg", strlen("avg"))) {
            // Пытаемся достать сохранённое количество замеров
            if (!hv_exists(hself, "_stats", strlen("_stats"))) {
                HV *inner_stats = (HV *)sv_2mortal((SV *)newHV());
                hv_store(hself, "_stats", strlen("_stats"), newRV((SV *)inner_stats), 0);
            }
            SV **_inner_stats = hv_fetch(hself, "_stats", strlen("_stats"), 0);
            if (!(_inner_stats && SvTYPE(SvRV(*_inner_stats)) == SVt_PVHV)) {
                croak("self->{_stats} expected to be a hashref");
            }
            HV *inner_stats = (HV *)(SvRV(*_inner_stats));
            if (!hv_exists(inner_stats, name, strlen(name))) {
                HV *inner_stats_metric = (HV *)sv_2mortal((SV *)newHV());
                hv_store(inner_stats_metric, "cnt", strlen("cnt"), newSVuv(0), 0);
                SV *r_inner_stats_metric = newRV((SV *)inner_stats_metric);
                hv_store(inner_stats, name, strlen(name), r_inner_stats_metric, 0);
            }
            SV **_inner_stats_metric = hv_fetch(inner_stats, name, strlen(name), 0);
            if (!(_inner_stats_metric && SvTYPE(SvRV(*_inner_stats_metric)) == SVt_PVHV)) {
                croak("self->{_stats}->{%s} expected to be a hashref", name);
            }
            HV *inner_stats_metric = (HV *)(SvRV(*_inner_stats_metric));
            if (!hv_exists(inner_stats_metric, "cnt", strlen("cnt"))) {
                hv_store(inner_stats_metric, "cnt", strlen("cnt"), newSVuv(0), 0);
            }
            SV **_inner_stats_metric_cnt = hv_fetch(inner_stats_metric, "cnt", strlen("cnt"), 0);
            if (!(_inner_stats_metric_cnt && SvTYPE(*_inner_stats_metric_cnt) == SVt_IV)) {
                croak("self->{_stats}->{%s}->{cnt} expected to be a uint", name);
            }
            unsigned int cnt;
            cnt = SvUV(*_inner_stats_metric_cnt);
            // Пересчитываем cnt и avg
            SV **_metric_stats_avg = hv_fetch(metric_stats, "avg", strlen("avg"), 0);
            if (!(_metric_stats_avg)) {
                croak("self->{stats}->{%s}->{avg} wasn't expected to be NULL", name);
            }
            double avg;
            if (SvTYPE(*_metric_stats_avg) == SVt_NULL) {
                cnt = 1;
                avg = value;
            } else {
                avg = SvNV(*_metric_stats_avg);
                avg = (avg * cnt + value) / (cnt + 1);
                ++cnt;
            }
            hv_store(metric_stats, "avg", strlen("avg"), newSVnv(avg), 0);
            // Сохраняем результат inner_stats
            hv_store(inner_stats_metric, "cnt", strlen("cnt"), newSVuv(cnt), 0);
            SV *rinner_stats_metric = newRV((SV *)inner_stats_metric);
            hv_store(inner_stats, name, strlen(name), rinner_stats_metric, 0);
            SV *rinner_stats = newRV((SV *)inner_stats);
            hv_store(hself, "_stats", strlen("_stats"), rinner_stats, 0);
            self = newRV((SV *)hself);
        }
        if (hv_exists(metric_stats, "cnt", strlen("cnt"))) {
            SV **_metric_stats_cnt = hv_fetch(metric_stats, "cnt", strlen("cnt"), 0);
            if (!(_metric_stats_cnt)) {
                croak("self->{stats}->{%s}->{cnt} wasn't expected to be NULL", name);
            }
            double cnt;
            if (SvTYPE(*_metric_stats_cnt) == SVt_NULL) {
                cnt = 1;
            } else {
                cnt = SvUV(*_metric_stats_cnt);
                ++cnt;
            }
            hv_store(metric_stats, "cnt", strlen("cnt"), newSVuv(cnt), 0);
        }
        if (hv_exists(metric_stats, "min", strlen("min"))) {
            SV **_metric_stats_min = hv_fetch(metric_stats, "min", strlen("min"), 0);
            if (!(_metric_stats_min)) {
                croak("self->{stats}->{%s}->{min} wasn't expected to be NULL", name);
            }
            double min;
            if (SvTYPE(*_metric_stats_min) == SVt_NULL) {
                min = value;
            } else {
                min = SvNV(*_metric_stats_min);
                if (value < min) {
                    min = value;
                }
            }
            hv_store(metric_stats, "min", strlen("min"), newSVnv(min), 0);
        }
        if (hv_exists(metric_stats, "max", strlen("max"))) {
            SV **_metric_stats_max = hv_fetch(metric_stats, "max", strlen("max"), 0);
            if (!(_metric_stats_max)) {
                croak("self->{stats}->{%s}->{max} wasn't expected to be NULL", name);
            }
            double max;
            if (SvTYPE(*_metric_stats_max) == SVt_NULL) {
                max = value;
            } else {
                max = SvNV(*_metric_stats_max);
                if (value > max) {
                    max = value;
                }
            }
            hv_store(metric_stats, "max", strlen("max"), newSVnv(max), 0);
        }
        if (hv_exists(metric_stats, "sum", strlen("sum"))) {
            SV **_metric_stats_sum = hv_fetch(metric_stats, "sum", strlen("sum"), 0);
            if (!(_metric_stats_sum)) {
                croak("self->{stats}->{%s}->{sum} wasn't expected to be NULL", name);
            }
            double sum;
            if (SvTYPE(*_metric_stats_sum) == SVt_NULL) {
                sum = value;
            } else {
                sum = SvNV(*_metric_stats_sum);
                sum += value;
            }
            hv_store(metric_stats, "sum", strlen("sum"), newSVnv(sum), 0);
        }
        // Обновляем информацию в объекте
        SV *rmetric_stats = newRV((SV *)metric_stats);
        hv_store(stats, name, strlen(name), rmetric_stats, 0);
        SV *rstats = newRV((SV *)stats);
        hv_store(hself, "stats", strlen("stats"), rstats, 0);
        self = newRV((SV *)hself);
        FREETMPS; LEAVE;


SV *stat(self)
    SV *self
    PPCODE:
        ENTER; SAVETMPS;
        if (!(SvOK(self) && SvROK(self))) {
            croak("self must be a hashref");
        }
        if (!(sv_isobject(self) && sv_isa(self, "Local::Stats"))) {
            croak("self must be an Local::Stats object");
        }
        HV *hself = (HV *)(SvRV(self));
        if (!hv_exists(hself, "stats", strlen("stats"))) {
            croak("self->{stats} key expected");
        }
        SV **_stats = hv_fetch(hself, "stats", strlen("stats"), 0);
        if (!_stats) {
            croak("self->{stats} hashref expected. NULL found");
        }
        HV *stats = (HV *)(SvRV(*_stats));
        hv_iterinit(stats);
        SV *_metric_stats;
        char *metric_name;
        int metric_name_length;
        HV *result_stats = (HV *)(sv_2mortal((SV *)newHV()));
        while ((_metric_stats = hv_iternextsv(stats, &metric_name, &metric_name_length))) {
            if (!SvTYPE(SvRV(_metric_stats)) == SVt_PVHV) {
                croak("Expected entries in self->{stats} to be hashrefs");
            }
            HV *metric_stats = (HV *)(SvRV(_metric_stats));
            hv_iterinit(metric_stats);
            SV *stat_value;
            char *stat_name;
            int stat_name_length;
            int keys_count = 0;
            HV *buffer_metric_stats = (HV *)sv_2mortal((SV *)newHV());
            while ((stat_value = hv_iternextsv(metric_stats, &stat_name, &stat_name_length))) {
                ++keys_count;
                hv_store(buffer_metric_stats, stat_name, stat_name_length, newSVsv(stat_value), 0);
                hv_store(metric_stats, stat_name, stat_name_length, newSV(0), 0);
            }
            if (keys_count > 0) {
                SV *rresult_metric_stats = newRV((SV *)buffer_metric_stats);
                hv_store(result_stats, metric_name, metric_name_length, rresult_metric_stats, 0);
            }
            SV *rmetric_stats = newRV((SV *)metric_stats);
            hv_store(stats, metric_name, metric_name_length, rmetric_stats, 0);
        }
        SV *rresult_stats = newRV((SV *)result_stats);
        FREETMPS; LEAVE;
        XPUSHs(sv_2mortal(rresult_stats));
