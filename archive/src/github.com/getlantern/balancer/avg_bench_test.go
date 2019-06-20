package balancer

/*
Not a benchmark actually. It's just to give us an sense how different
calculation of "average" looks like (Imagine the data points are random connect
time of an 500ms link vs 200ms link). Example result:

	benchmark_avg_test.go:50: d=450	avg=490	ravg1=584	ravg2=621	ravg3=622	||	d=110	avg=199	ravg1=92	ravg2=107	ravg3=119
	benchmark_avg_test.go:50: d=882	avg=491	ravg1=733	ravg2=708	ravg3=687	||	d=264	avg=199	ravg1=178	ravg2=159	ravg3=155
	benchmark_avg_test.go:50: d=190	avg=490	ravg1=461	ravg2=535	ravg3=562	||	d=109	avg=199	ravg1=143	ravg2=142	ravg3=143
	benchmark_avg_test.go:50: d=942	avg=491	ravg1=701	ravg2=670	ravg3=657	||	d=227	avg=199	ravg1=185	ravg2=170	ravg3=164
	benchmark_avg_test.go:50: d=238	avg=490	ravg1=469	ravg2=526	ravg3=552	||	d=11	avg=199	ravg1=98	ravg2=117	ravg3=125
	benchmark_avg_test.go:50: d=291	avg=490	ravg1=380	ravg2=447	ravg3=486	||	d=324	avg=199	ravg1=211	ravg2=186	ravg3=174
	benchmark_avg_test.go:50: d=204	avg=490	ravg1=292	ravg2=366	ravg3=415	||	d=123	avg=199	ravg1=167	ravg2=165	ravg3=161
	benchmark_avg_test.go:50: d=876	avg=490	ravg1=584	ravg2=536	ravg3=530	||	d=128	avg=199	ravg1=147	ravg2=152	ravg3=152
	benchmark_avg_test.go:50: d=35	avg=490	ravg1=309	ravg2=369	ravg3=406	||	d=127	avg=199	ravg1=137	ravg2=143	ravg3=145
	benchmark_avg_test.go:50: d=350	avg=490	ravg1=329	ravg2=362	ravg3=392	||	d=356	avg=199	ravg1=246	ravg2=214	ravg3=197
*/

/*import (
	"math/rand"
	"testing"
)

func BenchmarkAvg(b *testing.B) {
	total_A := 0
	recentAvg_A := 0
	recent2Avg_A := 0
	recent3Avg_A := 0

	total_B := 0
	recentAvg_B := 0
	recent2Avg_B := 0
	recent3Avg_B := 0
	for i := 0; i < b.N; i++ { //use b.N for looping
		d_A := rand.Intn(1000)
		total_A = total_A + d_A
		recentAvg_A = (recentAvg_A + d_A) / 2
		recent2Avg_A = (2*recent2Avg_A + d_A) / 3
		recent3Avg_A = (3*recent3Avg_A + d_A) / 4

		d_B := rand.Intn(400)
		total_B = total_B + d_B
		recentAvg_B = (recentAvg_B + d_B) / 2
		recent2Avg_B = (2*recent2Avg_B + d_B) / 3
		recent3Avg_B = (3*recent3Avg_B + d_B) / 4

		if i > 1000 {
			b.Logf("d=%d\tavg=%d\travg1=%d\travg2=%d\travg3=%d\t||\td=%d\tavg=%d\travg1=%d\travg2=%d\travg3=%d",
				d_A, total_A/(i+1), recentAvg_A, recent2Avg_A, recent3Avg_A,
				d_B, total_B/(i+1), recentAvg_B, recent2Avg_B, recent3Avg_B)
		}
	}
}*/
