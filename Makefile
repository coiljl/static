
dependencies: dependencies.json
	@packin install --folder $@ --meta $<
	@ln -snf .. $@/static
