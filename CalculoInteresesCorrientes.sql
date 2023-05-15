CREATE TABLE [dbo].[CTM](
	[idCT] [int] IDENTITY(1,1) NOT NULL,
	[idTarjetaMaestra] [int] NOT NULL,
	[Limite] [int] NULL,
	[SaldoActual] [int] NULL,
	[SaldoInteresesCorrientes] [int] NULL,
	[MontoDebitoInteresesCorrientes] [int] NULL,
	[TasaInteresCorriente] [int] NULL
 CONSTRAINT [PK_CTM] PRIMARY KEY CLUSTERED 
(
	[idCT] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE PROCEDURE ActualizarInteresesCorrientes
AS
BEGIN
	SET NOCOUNT ON;
	UPDATE CTM
	--Los dos primeros set corresponden a los que se mencionan en el documento
	--Se modifica el nombre de Saldo a SaldoActual
	--Se agregan SaldoInteresesCorrientes, MontoDebitoInteresesCorrientes y TasaInteresesCorrientes, esta �ltima se obtiene de una regla de negocio
	SET MontoDebitoInteresesCorrientes = SaldoActual / TasaInteresCorriente / 100 / 30, 
		SaldoInteresesCorrientes = SaldoInteresesCorrientes + MontoDebitoInteresesCorrientes,
		--El SaldoActual se modifica debido a lo que indica el documento: "El proceso de emisi�n de estados de cuenta se encarga de incorporar el 
		--SaldoInteresesCorrientes al Saldo Actual."
		SaldoActual = SaldoActual + SaldoInteresesCorrientes,
		--Se iguala a 0 para cumplir con lo siguiente: " El SaldoInteresesCorrientes debe 
		--quedar en cero para el siguiente ciclo (mes) para que acumule intereses nuevamente. "
		SaldoInteresesCorrientes = 0
	WHERE SaldoActual > 0;
	SET NOCOUNT OFF;
END;