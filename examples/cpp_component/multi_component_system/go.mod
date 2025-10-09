module example.com/multi-component-system

go 1.24

require (
	github.com/google/uuid v1.6.0
	go.bytecodealliance.org/cm v0.3.0
	golang.org/x/sync v0.10.0
)

replace example.com/multi-component-system => ./
