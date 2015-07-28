// +build darwin freebsd linux netbsd openbsd

package jibber_jabber_test

import (
	"fmt"
	. "github.com/pivotal-cf-experimental/jibber_jabber"
	"os"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

var _ = Describe("Unix", func() {
	AfterEach(func() {
		if err := os.Setenv("LC_ALL", ""); err != nil {
			fmt.Errorf("Unable to set environment variable: %v", err)
		}
		if err := os.Setenv("LANG", "en_US.UTF-8"); err != nil {
			fmt.Errorf("Unable to set environment variable: %v", err)
		}
	})

	Describe("#DetectIETF", func() {
		Context("Returns IETF encoded locale", func() {
			It("should return the locale set to LC_ALL", func() {
				if err := os.Setenv("LC_ALL", "fr_FR.UTF-8"); err != nil {
					fmt.Errorf("Unable to set environment variable: %v", err)
				}
				result, _ := DetectIETF()
				Ω(result).Should(Equal("fr-FR"))
			})

			It("should return the locale set to LANG if LC_ALL isn't set", func() {
				if err := os.Setenv("LANG", "fr_FR.UTF-8"); err != nil {
					fmt.Errorf("Unable to set environment variable: %v", err)
				}

				result, _ := DetectIETF()
				Ω(result).Should(Equal("fr-FR"))
			})

			It("should return an error if it cannot detect a locale", func() {
				if err := os.Setenv("LANG", ""); err != nil {
					fmt.Errorf("Unable to set environment variable: %v", err)
				}

				_, err := DetectIETF()
				Ω(err.Error()).Should(Equal(COULD_NOT_DETECT_PACKAGE_ERROR_MESSAGE))
			})
		})

		Context("when the locale is simply 'fr'", func() {
			BeforeEach(func() {
				if err := os.Setenv("LANG", "fr"); err != nil {
					fmt.Errorf("Unable to set environment variable: %v", err)
				}
			})

			It("should return the locale without a territory", func() {
				language, err := DetectIETF()
				Ω(err).ShouldNot(HaveOccurred())
				Ω(language).Should(Equal("fr"))
			})
		})
	})

	Describe("#DetectLanguage", func() {
		Context("Returns encoded language", func() {
			It("should return the language set to LC_ALL", func() {
				if err := os.Setenv("LC_ALL", "fr_FR.UTF-8"); err != nil {
					fmt.Errorf("Unable to set environment variable: %v", err)
				}
				result, _ := DetectLanguage()
				Ω(result).Should(Equal("fr"))
			})

			It("should return the language set to LANG if LC_ALL isn't set", func() {
				if err := os.Setenv("LANG", "fr_FR.UTF-8"); err != nil {
					fmt.Errorf("Unable to set environment variable: %v", err)
				}

				result, _ := DetectLanguage()
				Ω(result).Should(Equal("fr"))
			})

			It("should return an error if it cannot detect a language", func() {
				if err := os.Setenv("LANG", ""); err != nil {
					fmt.Errorf("Unable to set environment variable: %v", err)
				}

				_, err := DetectLanguage()
				Ω(err.Error()).Should(Equal(COULD_NOT_DETECT_PACKAGE_ERROR_MESSAGE))
			})
		})
	})

	Describe("#DetectTerritory", func() {
		Context("Returns encoded territory", func() {
			It("should return the territory set to LC_ALL", func() {
				if err := os.Setenv("LC_ALL", "fr_FR.UTF-8"); err != nil {
					fmt.Errorf("Unable to set environment variable: %v", err)
				}
				result, _ := DetectTerritory()
				Ω(result).Should(Equal("FR"))
			})

			It("should return the territory set to LANG if LC_ALL isn't set", func() {
				if err := os.Setenv("LANG", "fr_FR.UTF-8"); err != nil {
					fmt.Errorf("Unable to set environment variable: %v", err)
				}

				result, _ := DetectTerritory()
				Ω(result).Should(Equal("FR"))
			})

			It("should return an error if it cannot detect a territory", func() {
				if err := os.Setenv("LANG", ""); err != nil {
					fmt.Errorf("Unable to set environment variable: %v", err)
				}

				_, err := DetectTerritory()
				Ω(err.Error()).Should(Equal(COULD_NOT_DETECT_PACKAGE_ERROR_MESSAGE))
			})
		})
	})

})
