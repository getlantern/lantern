// package cfr provides utilities for interaction with cloudfront
package cfr

import (
	"crypto/tls"
	"encoding/xml"
	"fmt"
	"net/http"
	"strconv"
	"time"

	"github.com/getlantern/aws-sdk-go/aws"
	"github.com/getlantern/aws-sdk-go/gen/cloudfront"
	"github.com/getlantern/golog"
)

const (
	listBatchSize = 100
	xmlSpace      = "http://cloudfront.amazonaws.com/doc/2014-10-21/"
)

var (
	log = golog.LoggerFor("cfr")
)

type Distribution struct {
	// "": we haven't even started bringing up this distribution
	// "InProgress": distribution is getting set up
	// "Deployed": distribution is ready to serve
	Status string
	// FQDN of this distribution
	Domain string
	// Lantern instance ID of the server that this distribution points to.
	InstanceId string
	// Free-form description of the purpose of this distribution.
	Comment string
	// Whether this distribution is enabled (currently only used for
	// deleting distributions)
	Enabled bool
	// ID used to refer to this distribution in the CloudFront API.
	distributionId aws.StringValue
}

func New(id string, key string, httpClient *http.Client) *cloudfront.CloudFront {
	creds := aws.Creds(id, key, "")
	// Set a longish timeout on the HTTP client just in case
	if httpClient == nil {
		httpClient = &http.Client{
			Timeout: 5 * time.Minute,
			Transport: &http.Transport{
				TLSClientConfig: &tls.Config{
					ClientSessionCache: tls.NewLRUClientSessionCache(1000),
				},
			},
		}
	}
	return cloudfront.New(creds, "", httpClient)
}

func CreateDistribution(cfr *cloudfront.CloudFront, name string, originDomain string, comment string) (*Distribution, error) {
	nameStr := aws.String(name)
	req := cloudfront.CreateDistributionRequest{
		DistributionConfig: &cloudfront.DistributionConfig{
			Logging: &cloudfront.LoggingConfig{
				XMLName: xml.Name{
					Space: xmlSpace,
					Local: "Logging",
				},
				Bucket:         aws.String("-"),
				Enabled:        aws.False(),
				IncludeCookies: aws.False(),
				Prefix:         aws.String("-"),
			},
			Origins: &cloudfront.Origins{
				Items: []cloudfront.Origin{
					cloudfront.Origin{
						ID:         nameStr,
						DomainName: aws.String(originDomain),
						CustomOriginConfig: &cloudfront.CustomOriginConfig{
							HTTPPort:             aws.Integer(80),
							HTTPSPort:            aws.Integer(443),
							OriginProtocolPolicy: aws.String(cloudfront.OriginProtocolPolicyHTTPOnly),
						},
					},
				},
				Quantity: aws.Integer(1),
			},
			CacheBehaviors: &cloudfront.CacheBehaviors{
				Items:    []cloudfront.CacheBehavior{},
				Quantity: aws.Integer(0),
			},
			DefaultCacheBehavior: &cloudfront.DefaultCacheBehavior{
				TargetOriginID: nameStr,
				AllowedMethods: &cloudfront.AllowedMethods{
					CachedMethods: &cloudfront.CachedMethods{
						Items: []string{
							cloudfront.MethodGet,
							cloudfront.MethodHead,
						},
						Quantity: aws.Integer(2),
					},
					Items: []string{
						cloudfront.MethodPost,
						cloudfront.MethodPatch,
						cloudfront.MethodGet,
						cloudfront.MethodDelete,
						cloudfront.MethodOptions,
						cloudfront.MethodPut,
						cloudfront.MethodHead,
					},
					Quantity: aws.Integer(7),
				},
				ForwardedValues: &cloudfront.ForwardedValues{
					Cookies: &cloudfront.CookiePreference{
						XMLName: xml.Name{
							Space: xmlSpace,
							Local: "Cookies",
						},
						Forward: aws.String(cloudfront.ItemSelectionNone),
					},
					Headers: &cloudfront.Headers{
						Items: []string{
							"X-Enproxy-Id",
							"X-Enproxy-Dest-Addr",
							"X-Enproxy-EOF",
							"X-Enproxy-Proxy-Host",
							"X-Enproxy-Op",
						},
						Quantity: aws.Integer(5),
					},
					QueryString: aws.False(),
				},
				ViewerProtocolPolicy: aws.String(cloudfront.ViewerProtocolPolicyHTTPSOnly),
				MinTTL:               aws.Long(0),
				TrustedSigners: &cloudfront.TrustedSigners{
					Enabled:  aws.False(),
					Items:    []string{},
					Quantity: aws.Integer(0),
				},
			},
			Comment:           aws.String(comment),
			PriceClass:        aws.String(cloudfront.PriceClassPriceClassAll),
			Enabled:           aws.True(),
			DefaultRootObject: aws.String(""),
			Aliases: &cloudfront.Aliases{
				Items:    []string{},
				Quantity: aws.Integer(0),
			},
			CallerReference: nameStr,
		},
	}
	result, err := cfr.CreateDistribution(&req)
	if err != nil {
		return nil, err
	}
	return &Distribution{
		Status:         "InProgress",
		Domain:         *result.Distribution.DomainName,
		InstanceId:     name,
		Comment:        comment,
		Enabled:        true,
		distributionId: result.Distribution.ID,
	}, nil
}

func ListDistributions(cfr *cloudfront.CloudFront) ([]*Distribution, error) {
	req := cloudfront.ListDistributionsRequest{}
	req.MaxItems = aws.String(strconv.Itoa(listBatchSize))
	ret := make([]*Distribution, 0, listBatchSize)
	for {
		resp, err := cfr.ListDistributions(&req)
		if err != nil {
			return nil, err
		}
		nitems := *resp.DistributionList.Quantity
		for i := 0; i < nitems; i++ {
			cfrDist := resp.DistributionList.Items[i]
			dist := Distribution{
				Status:         *cfrDist.Status,
				Domain:         *cfrDist.DomainName,
				InstanceId:     *cfrDist.DefaultCacheBehavior.TargetOriginID,
				Comment:        *cfrDist.Comment,
				Enabled:        *cfrDist.Enabled,
				distributionId: cfrDist.ID,
			}
			ret = append(ret, &dist)
		}
		if resp.DistributionList.NextMarker == nil {
			break
		}
		req.Marker = resp.DistributionList.NextMarker
	}
	return ret, nil
}

func RefreshStatus(cfr *cloudfront.CloudFront, dist *Distribution) error {
	req := &cloudfront.GetDistributionRequest{ID: dist.distributionId}
	resp, err := cfr.GetDistribution(req)
	if err != nil {
		return err
	}
	dist.Status = *resp.Distribution.Status
	return nil
}

func DisableDistribution(cfr *cloudfront.CloudFront, dist *Distribution) error {
	// See:
	// http://docs.aws.amazon.com/AmazonCloudFront/latest/APIReference/DeleteDistribution.html
	getreq := &cloudfront.GetDistributionConfigRequest{ID: dist.distributionId}
	getresp, err := cfr.GetDistributionConfig(getreq)
	if err != nil {
		return err
	}
	getresp.DistributionConfig.Enabled = aws.False()
	setreq := &cloudfront.UpdateDistributionRequest{
		ID:                 dist.distributionId,
		IfMatch:            getresp.ETag,
		DistributionConfig: getresp.DistributionConfig,
	}
	setresp, err := cfr.UpdateDistribution(setreq)
	if err != nil {
		return err
	}
	if *setresp.Distribution.DistributionConfig.Enabled != false {
		return fmt.Errorf("Attempt to disable distribution had no effect")
	}
	dist.Enabled = false
	dist.Status = "InProgress"
	return nil
}

func DeleteDistribution(cfr *cloudfront.CloudFront, dist *Distribution) error {
	// See:
	// http://docs.aws.amazon.com/AmazonCloudFront/latest/APIReference/DeleteDistribution.html
	getreq := &cloudfront.GetDistributionConfigRequest{ID: dist.distributionId}
	getresp, err := cfr.GetDistributionConfig(getreq)
	if err != nil {
		return err
	}
	delreq := &cloudfront.DeleteDistributionRequest{
		ID:      dist.distributionId,
		IfMatch: getresp.ETag,
	}
	return cfr.DeleteDistribution(delreq)
}
