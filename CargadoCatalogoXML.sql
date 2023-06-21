CREATE PROCEDURE [dbo].[SP_RegistrarCatalogo]
    @inRutaXML NVARCHAR(500),
	@OutResult INT OUTPUT
AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		DECLARE @Datos xml/*Declaramos la variable Datos como un tipo XML*/
		DECLARE @Comando NVARCHAR(500)= 'SELECT @Datos = D FROM OPENROWSET (BULK '  + CHAR(39) + @inRutaXML + CHAR(39) + ', SINGLE_BLOB) AS Datos(D)' -- comando que va a ejecutar el sql dinamico
		DECLARE @Parametros NVARCHAR(500)
		SET @Parametros = N'@Datos xml OUTPUT' --parametros del sql dinamico
		EXECUTE sp_executesql @Comando, @Parametros, @Datos OUTPUT -- ejecutamos el comando que hicimos dinamicamente
		DECLARE @hdoc int /*Creamos hdoc que va a ser un identificador*/
		EXEC sp_xml_preparedocument @hdoc OUTPUT, @Datos/*Toma el identificador y a la variable con el documento y las asocia*/
		BEGIN
			BEGIN TRANSACTION InsercionDatos
				INSERT INTO [dbo].[TipoDocumentoIdentidad] --TipoDocId
							([Nombre]
							,[Formato])
				SELECT Nombre, Formato
				FROM OPENXML (@hdoc,  '/root/TDI/TDI' , 1)
				WITH(
					Nombre VARCHAR(100) '@Nombre',
					Formato VARCHAR(100) '@Formato'
				)

				INSERT INTO [dbo].[TipoCuentaTarjetaMaestra]		
							([Nombre])
				SELECT Nombre
				FROM OPENXML (@hdoc,  '/root/TCTM/TCTM' , 1)
				WITH(
					Nombre VARCHAR(100) '@Nombre'
				)

				INSERT INTO [dbo].[TipoReglaNegocio]		
							([Nombre]
							,[Tipo])
				SELECT Nombre, Tipo
				FROM OPENXML (@hdoc,  '/root/TRN/TRN' , 1)
				WITH(
					Nombre VARCHAR(100) '@Nombre',
					Tipo VARCHAR(100) '@tipo'
				)

				INSERT INTO [dbo].[ReglaNegocio]		
							([idTipoReglaNegocio]
							,[Nombre]
							,[TipoCuentaTarjetaMaestra]
							,[TipoReglaNegocio]
							,[Valor])
				SELECT TRN.id, RN.Nombre, RN.TipoCuentaTarjetaMaestra, RN.TipoReglaNegocio, RN.Valor
				FROM OPENXML (@hdoc,  '/root/RN/RN' , 1)
				WITH(
					idTipoReglaNegocio INT,
					Nombre VARCHAR(100) '@Nombre',
					TipoCuentaTarjetaMaestra VARCHAR(100) '@TCTM',
					TipoReglaNegocio VARCHAR(100) '@TipoRN',
					Valor VARCHAR(100) '@Valor'
				)AS RN
				INNER JOIN TipoReglaNegocio AS TRN ON TRN.nombre = RN.TipoReglaNegocio;
				

				INSERT INTO [dbo].[MotivoInvalidacionTarjeta]
							([Nombre])
				SELECT Nombre
				FROM OPENXML (@hdoc,  '/root/MIT/MIT' , 1)
				WITH(
					id INT,
					Nombre VARCHAR(100) '@Nombre'
				)

				INSERT INTO [dbo].[TipoMovimiento]
							([Nombre]
							,[Accion]
							,[Acumula_Operacion_ATM]
							,[Acumula_Operacion_Ventana])
				SELECT Nombre, Accion, Acumula_Operacion_ATM, Acumula_Operacion_Ventana
				FROM OPENXML (@hdoc,  '/root/TM/TM' , 1)
				WITH(
					Nombre VARCHAR(100) '@Nombre',
					Accion VARCHAR(100) '@Accion',
					Acumula_Operacion_ATM VARCHAR(100) '@Acumula_Operacion_ATM',
					Acumula_Operacion_Ventana VARCHAR(100) '@Acumula_Operacion_Ventana'
				)

				INSERT INTO [dbo].[UsuarioAdministrador]
							([Nombre]
							,[Password])
				SELECT Nombre, Password
				FROM OPENXML (@hdoc,  '/root/UA/Usuario' , 1)
				WITH(
					Nombre VARCHAR(100) '@Nombre',
					Password VARCHAR(100) '@Password'
				)

				INSERT INTO [dbo].[TipoMovimientoTablaIntereses]
							([Nombre]
							,[Accion])
				SELECT Nombre, Accion
				FROM OPENXML (@hdoc,  '/root/TMTI/TMTI' , 1)
				WITH(
					Nombre VARCHAR(100) '@Nombre',
					Accion VARCHAR(100) '@Accion'
				)
				EXEC sp_xml_removedocument @hdoc/*Remueve el documento XML de la memoria*/
				SET NOCOUNT OFF;
			COMMIT TRANSACTION
		END;
	END TRY
	BEGIN CATCH
		IF @@TRANCOUNT > 0
		BEGIN
			ROLLBACK TRANSACTION InsercionDatos
		END 
		INSERT INTO dbo.DBErrors
			(
			[UserName]
			,[ErrorNumber]
			,[ErrorState]
			,[ErrorSeverity]
			,[ErrorLine]
			,[ErrorProcedure]
			,[ErrorMessage]
			,[ErrorDateTime]
			)
			VALUES 
			(
			SUSER_SNAME()
			, ERROR_NUMBER()
			, ERROR_STATE()
			, ERROR_SEVERITY()
			, ERROR_LINE()
			, ERROR_PROCEDURE()
			, ERROR_MESSAGE()
			, GETDATE()
			);
			SET @OutResult =500001
	END CATCH
END;
GO